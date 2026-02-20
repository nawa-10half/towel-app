import Foundation
import FirebaseAuth
import FirebaseFirestore
import Security

@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()

    var currentUser: FirebaseAuth.User?
    var isAuthenticated = false
    var isLoading = true
    var isDeletingAccount = false
    var errorMessage: String?
    var displayName: String = ""
    var restoreCode: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private var hasAttemptedAutoSignIn = false

    private static let keychainService = "com.kaetao-app.TowelApp"
    private static let keychainKeyRestoreCode = "restoreCode"
    // 紛らわしい文字 (0/O, 1/I/L) を除いた文字セット
    static let codeCharacters = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")

    private init() {
        restoreCode = loadFromKeychain(key: Self.keychainKeyRestoreCode)
        setupAuthListener()
    }

    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                Task { await self.loadDisplayName(uid: user.uid) }
            } else if !self.hasAttemptedAutoSignIn, let code = self.restoreCode {
                // Keychain にコードがあれば自動サインイン
                self.hasAttemptedAutoSignIn = true
                Task {
                    await self.signInWithRestoreCode(code)
                    if !self.isAuthenticated {
                        self.isLoading = false
                    }
                }
            } else {
                self.currentUser = nil
                self.isAuthenticated = false
                self.isLoading = false
            }
        }
    }

    // MARK: - Sign In with Restore Code

    func signInWithRestoreCode(_ code: String) async {
        guard let urlString = Bundle.main.infoDictionary?["RestoreCodeAuthURL"] as? String,
              let apiURL = URL(string: urlString) else {
            errorMessage = "API URLの設定が見つかりません"
            return
        }

        do {
            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["code": code])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "コードが無効です"
                return
            }

            let json = try JSONDecoder().decode([String: String].self, from: data)
            guard let customToken = json["customToken"] else {
                errorMessage = "認証トークンの取得に失敗しました"
                return
            }

            try await Auth.auth().signIn(withCustomToken: customToken)
            saveToKeychain(code, key: Self.keychainKeyRestoreCode)
            self.restoreCode = code
        } catch {
            errorMessage = "サインインに失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Display Name

    func loadDisplayName(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            self.displayName = doc.data()?["displayName"] as? String ?? ""
        } catch {
            // ネットワークエラー等は無視
        }
    }

    func updateDisplayName(_ name: String) async throws {
        guard let uid = currentUser?.uid else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await db.collection("users").document(uid).updateData(["displayName": trimmed])
        self.displayName = trimmed

        // グループメンバードキュメントにも同期
        if let groupId = GroupService.shared.groupId {
            try await db.collection("groups").document(groupId)
                .collection("members").document(uid)
                .updateData(["displayName": trimmed])
        }
    }

    // MARK: - Ensure User Document (初回サインイン時)

    func ensureUserDocument(displayName: String) async throws {
        guard let uid = currentUser?.uid else { return }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let docRef = db.collection("users").document(uid)
        let doc = try await docRef.getDocument()

        if !doc.exists {
            try await docRef.setData([
                "displayName": trimmed,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            self.displayName = trimmed
        } else {
            try await docRef.updateData(["updatedAt": FieldValue.serverTimestamp()])
        }
    }

    // MARK: - Sign Out

    func signOut() {
        // リスナーを先に停止（サインアウト後の権限エラーを防ぐ）
        FirestoreService.shared.stopListening()
        GroupService.shared.stopListening()
        do {
            try Auth.auth().signOut()
            displayName = ""
        } catch {
            // サインアウト失敗時はリスナーを再開
            FirestoreService.shared.startListening()
            errorMessage = "サインアウトに失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        guard let user = Auth.auth().currentUser else { return }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        // 1. グループから退出
        await GroupService.shared.handleAccountDeletion()

        // 2. Firestore リスナー停止
        FirestoreService.shared.stopListening()

        // 3. Storage 写真削除（ベストエフォート）
        let towelsSnapshot = FirestoreService.shared.towels
        await StorageService.shared.deleteAllUserPhotos(towels: towelsSnapshot)

        // 4. Firestore データ削除
        do {
            try await FirestoreService.shared.deleteAllTowels()
            try await FirestoreService.shared.deleteUserDocument()
        } catch {
            // 一部失敗しても続行
        }

        // 5. リストアコードを Firestore から削除
        if let code = restoreCode {
            try? await db.collection("restoreCodes").document(code).delete()
        }

        // 6. Firebase Auth ユーザー削除
        do {
            try await user.delete()
            deleteFromKeychain(key: Self.keychainKeyRestoreCode)
            restoreCode = nil
            displayName = ""
        } catch {
            errorMessage = "アカウント削除に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Code Generation

    func generateRestoreCode() -> String {
        let group1 = String((0..<4).map { _ in Self.codeCharacters.randomElement()! })
        let group2 = String((0..<4).map { _ in Self.codeCharacters.randomElement()! })
        let group3 = String((0..<4).map { _ in Self.codeCharacters.randomElement()! })
        return "\(group1)-\(group2)-\(group3)"
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
