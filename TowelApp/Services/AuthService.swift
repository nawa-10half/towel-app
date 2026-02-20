import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import GoogleSignIn
import CryptoKit

@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()

    var currentUser: FirebaseAuth.User?
    var isAuthenticated = false
    var isLoading = true
    var isDeletingAccount = false
    var errorMessage: String?

    /// Authorization code obtained during Apple reauthentication (for token revocation)
    var appleAuthorizationCode: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    private init() {
        setupAuthListener()
    }

    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.currentUser = user
            self.isAuthenticated = user != nil
            self.isLoading = false
        }
    }

    // MARK: - Apple Sign In

    func handleAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Appleサインインの処理に失敗しました"
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                try await ensureUserDocument(for: authResult.user)
            } catch {
                errorMessage = "サインインに失敗しました: \(error.localizedDescription)"
            }

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Appleサインインに失敗しました: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "画面の取得に失敗しました"
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google IDトークンの取得に失敗しました"
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            try await ensureUserDocument(for: authResult.user)
        } catch {
            if (error as NSError).code != GIDSignInError.canceled.rawValue {
                errorMessage = "Googleサインインに失敗しました: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            errorMessage = "サインアウトに失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Apple Reauthentication

    /// Handle Apple reauthentication for account deletion (reuses nonce logic)
    func reauthenticateWithApple(_ result: Result<ASAuthorization, Error>) async -> Bool {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple再認証の処理に失敗しました"
                return false
            }

            // Store authorization code for token revocation
            if let authCode = appleIDCredential.authorizationCode,
               let authCodeString = String(data: authCode, encoding: .utf8) {
                appleAuthorizationCode = authCodeString
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            do {
                try await Auth.auth().currentUser?.reauthenticate(with: credential)
                return true
            } catch {
                errorMessage = "再認証に失敗しました: \(error.localizedDescription)"
                return false
            }

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple再認証に失敗しました: \(error.localizedDescription)"
            }
            return false
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        guard let user = Auth.auth().currentUser else { return }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            // 1. Delete all photos from Storage (needs auth for userId path resolution)
            await StorageService.shared.deleteAllUserPhotos(towels: FirestoreService.shared.towels)

            // 2. Stop Firestore listeners to prevent UI crashes during deletion
            FirestoreService.shared.stopListening()

            // 3. Delete all towels + subcollections
            try await FirestoreService.shared.deleteAllTowels()

            // 4. Delete user document
            try await FirestoreService.shared.deleteUserDocument()

            // 5. Revoke Apple token if authorization code is available
            if let authCode = appleAuthorizationCode {
                try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
                appleAuthorizationCode = nil
            }

            // 6. Delete the Firebase Auth user
            try await user.delete()
        } catch {
            errorMessage = "アカウント削除に失敗しました: \(error.localizedDescription)"
            // Re-start listeners since deletion failed
            FirestoreService.shared.startListening()
        }
    }

    // MARK: - Private Helpers

    private func ensureUserDocument(for user: FirebaseAuth.User) async throws {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(user.uid)
        let doc = try await docRef.getDocument()

        if !doc.exists {
            try await docRef.setData([
                "displayName": user.displayName as Any,
                "email": user.email as Any,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } else {
            try await docRef.updateData([
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
