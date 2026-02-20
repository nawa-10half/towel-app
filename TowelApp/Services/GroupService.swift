import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
@MainActor
final class GroupService {
    static let shared = GroupService()

    var group: FamilyGroup?
    var members: [GroupMember] = []
    var groupId: String?
    var isLoading = false
    var errorMessage: String?

    private let db = Firestore.firestore()
    private var groupListener: ListenerRegistration?
    private var membersListener: ListenerRegistration?

    private static let inviteCodeCharacters = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    private static let inviteCodeLength = 6
    private static let maxMembers = 10
    private static let maxInviteCodeRetries = 5

    private init() {}

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Load Group for Current User

    func loadGroupForCurrentUser() async {
        guard let userId else { return }

        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let loadedGroupId = doc.data()?["groupId"] as? String
            self.groupId = loadedGroupId

            if let loadedGroupId {
                startListening(groupId: loadedGroupId)
            }
        } catch {
            errorMessage = "グループ情報の読み込みに失敗しました"
        }
    }

    // MARK: - Listening

    func startListening(groupId: String) {
        stopListening()

        groupListener = db.collection("groups").document(groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = "グループの読み込みに失敗しました: \(error.localizedDescription)"
                    return
                }
                self.group = try? snapshot?.data(as: FamilyGroup.self)
            }

        membersListener = db.collection("groups").document(groupId).collection("members")
            .order(by: "joinedAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                self.members = documents.compactMap { try? $0.data(as: GroupMember.self) }
            }
    }

    func stopListening() {
        groupListener?.remove()
        groupListener = nil
        membersListener?.remove()
        membersListener = nil
    }

    // MARK: - Create Group

    func createGroup(name: String) async throws {
        guard let userId else { throw GroupError.notAuthenticated }
        guard groupId == nil else { throw GroupError.alreadyInGroup }

        isLoading = true
        defer { isLoading = false }

        let inviteCode = try await generateUniqueInviteCode()

        let groupRef = db.collection("groups").document()
        let newGroupId = groupRef.documentID

        let groupData: [String: Any] = [
            "name": name,
            "inviteCode": inviteCode,
            "createdBy": userId,
            "memberCount": 1,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let user = Auth.auth().currentUser
        let memberData: [String: Any] = [
            "displayName": user?.displayName as Any,
            "email": user?.email as Any,
            "role": "owner",
            "joinedAt": FieldValue.serverTimestamp()
        ]

        let inviteCodeData: [String: Any] = [
            "groupId": newGroupId,
            "createdAt": FieldValue.serverTimestamp()
        ]

        let batch = db.batch()
        batch.setData(groupData, forDocument: groupRef)
        batch.setData(memberData, forDocument: groupRef.collection("members").document(userId))
        batch.setData(inviteCodeData, forDocument: db.collection("inviteCodes").document(inviteCode))
        batch.updateData(["groupId": newGroupId], forDocument: db.collection("users").document(userId))
        try await batch.commit()

        self.groupId = newGroupId

        // Migrate existing personal towels to the group
        try await migrateTowelsToGroup(groupId: newGroupId)

        // Restart Firestore listener on new path
        FirestoreService.shared.stopListening()
        FirestoreService.shared.startListening()

        startListening(groupId: newGroupId)
    }

    // MARK: - Join Group

    func joinGroup(inviteCode: String) async throws {
        guard let userId else { throw GroupError.notAuthenticated }
        guard groupId == nil else { throw GroupError.alreadyInGroup }

        isLoading = true
        defer { isLoading = false }

        let code = inviteCode.uppercased()

        // Look up invite code
        let codeDoc = try await db.collection("inviteCodes").document(code).getDocument()
        guard let codeData = codeDoc.data(),
              let targetGroupId = codeData["groupId"] as? String else {
            throw GroupError.invalidInviteCode
        }

        // Check member count
        let groupDoc = try await db.collection("groups").document(targetGroupId).getDocument()
        guard let groupData = groupDoc.data() else { throw GroupError.groupNotFound }
        let currentCount = groupData["memberCount"] as? Int ?? 0
        guard currentCount < Self.maxMembers else { throw GroupError.groupFull }

        let user = Auth.auth().currentUser
        let memberData: [String: Any] = [
            "displayName": user?.displayName as Any,
            "email": user?.email as Any,
            "role": "member",
            "joinedAt": FieldValue.serverTimestamp()
        ]

        let groupRef = db.collection("groups").document(targetGroupId)

        // Step 1: Add self as member first (rules allow create on own memberId)
        try await groupRef.collection("members").document(userId).setData(memberData)

        // Step 2: Now isMember() passes — update group and user docs
        let batch = db.batch()
        batch.updateData([
            "memberCount": FieldValue.increment(Int64(1)),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: groupRef)
        batch.updateData(["groupId": targetGroupId], forDocument: db.collection("users").document(userId))
        try await batch.commit()

        self.groupId = targetGroupId

        // Migrate existing personal towels to the group
        try await migrateTowelsToGroup(groupId: targetGroupId)

        // Restart Firestore listener on new path
        FirestoreService.shared.stopListening()
        FirestoreService.shared.startListening()

        startListening(groupId: targetGroupId)
    }

    // MARK: - Leave Group

    func leaveGroup() async throws {
        guard let userId else { throw GroupError.notAuthenticated }
        guard let currentGroupId = groupId else { throw GroupError.notInGroup }

        isLoading = true
        defer { isLoading = false }

        // リスナーを先に停止（削除処理中に権限エラーが発火するのを防ぐ）
        stopListening()
        FirestoreService.shared.stopListening()

        let memberCount = group?.memberCount ?? members.count

        if memberCount <= 1 {
            // Last member — delete the entire group
            try await deleteGroup(groupId: currentGroupId)
        } else {
            // Remove self from members and decrement count
            let batch = db.batch()
            let groupRef = db.collection("groups").document(currentGroupId)
            batch.deleteDocument(groupRef.collection("members").document(userId))
            batch.updateData([
                "memberCount": FieldValue.increment(Int64(-1)),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: groupRef)
            batch.updateData(["groupId": FieldValue.delete()], forDocument: db.collection("users").document(userId))
            try await batch.commit()
        }

        self.groupId = nil
        self.group = nil
        self.members = []

        // Restart Firestore listener on personal path
        FirestoreService.shared.startListening()
    }

    // MARK: - Regenerate Invite Code

    func regenerateInviteCode() async throws {
        guard let currentGroupId = groupId else { throw GroupError.notInGroup }
        guard let oldCode = group?.inviteCode else { return }

        isLoading = true
        defer { isLoading = false }

        let newCode = try await generateUniqueInviteCode()

        let batch = db.batch()
        batch.deleteDocument(db.collection("inviteCodes").document(oldCode))
        batch.setData([
            "groupId": currentGroupId,
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: db.collection("inviteCodes").document(newCode))
        batch.updateData([
            "inviteCode": newCode,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: db.collection("groups").document(currentGroupId))
        try await batch.commit()
    }

    // MARK: - Account Deletion

    func handleAccountDeletion() async {
        guard groupId != nil else { return }
        try? await leaveGroup()
    }

    // MARK: - Towel Migration

    func migrateTowelsToGroup(groupId: String) async throws {
        guard let userId else { return }

        let personalTowels = try await db.collection("users").document(userId)
            .collection("towels").getDocuments()

        guard !personalTowels.documents.isEmpty else { return }

        let groupTowelsRef = db.collection("groups").document(groupId).collection("towels")

        for towelDoc in personalTowels.documents {
            var towelData = towelDoc.data()
            towelData["addedBy"] = userId

            // Create towel in group
            let newTowelRef = groupTowelsRef.document(towelDoc.documentID)
            try await newTowelRef.setData(towelData)

            // Copy records subcollection
            let records = try await towelDoc.reference.collection("records").getDocuments()
            for record in records.documents {
                try await newTowelRef.collection("records").document(record.documentID)
                    .setData(record.data())
            }

            // Copy conditionChecks subcollection + photos
            let checks = try await towelDoc.reference.collection("conditionChecks").getDocuments()
            for check in checks.documents {
                var checkData = check.data()

                // Copy photo if exists
                if checkData["photoURL"] != nil {
                    let sourcePath = "users/\(userId)/towels/\(towelDoc.documentID)/conditions/\(check.documentID).jpg"
                    let destPath = "groups/\(groupId)/towels/\(towelDoc.documentID)/conditions/\(check.documentID).jpg"
                    if let newURL = try? await StorageService.shared.copyPhoto(fromPath: sourcePath, toPath: destPath) {
                        checkData["photoURL"] = newURL
                    }
                }

                try await newTowelRef.collection("conditionChecks").document(check.documentID)
                    .setData(checkData)
            }
        }

        // Delete original personal data after successful copy
        for towelDoc in personalTowels.documents {
            // Delete subcollections first
            let records = try await towelDoc.reference.collection("records").getDocuments()
            for record in records.documents {
                try await record.reference.delete()
            }
            let checks = try await towelDoc.reference.collection("conditionChecks").getDocuments()
            for check in checks.documents {
                // Delete personal photo
                if check.data()["photoURL"] != nil {
                    try? await StorageService.shared.deletePhoto(
                        path: "users/\(userId)/towels/\(towelDoc.documentID)/conditions/\(check.documentID).jpg"
                    )
                }
                try await check.reference.delete()
            }
            try await towelDoc.reference.delete()
        }
    }

    // MARK: - Private Helpers

    private func generateUniqueInviteCode() async throws -> String {
        for _ in 0..<Self.maxInviteCodeRetries {
            let code = generateInviteCode()
            let doc = try await db.collection("inviteCodes").document(code).getDocument()
            if !doc.exists {
                return code
            }
        }
        throw GroupError.inviteCodeGenerationFailed
    }

    private func generateInviteCode() -> String {
        String((0..<Self.inviteCodeLength).map { _ in
            Self.inviteCodeCharacters.randomElement()!
        })
    }

    private func deleteGroup(groupId: String) async throws {
        guard let userId else { return }

        // Delete all towels and their subcollections
        let towels = try await db.collection("groups").document(groupId)
            .collection("towels").getDocuments()
        for towelDoc in towels.documents {
            let records = try await towelDoc.reference.collection("records").getDocuments()
            for record in records.documents {
                try await record.reference.delete()
            }
            let checks = try await towelDoc.reference.collection("conditionChecks").getDocuments()
            for check in checks.documents {
                // Delete group photo
                if check.data()["photoURL"] != nil {
                    try? await StorageService.shared.deletePhoto(
                        path: "groups/\(groupId)/towels/\(towelDoc.documentID)/conditions/\(check.documentID).jpg"
                    )
                }
                try await check.reference.delete()
            }
            try await towelDoc.reference.delete()
        }

        // Delete invite code（まだメンバーのうちに削除）
        if let inviteCode = group?.inviteCode {
            try await db.collection("inviteCodes").document(inviteCode).delete()
        }

        // Delete group document（まだメンバーのうちに削除）
        try await db.collection("groups").document(groupId).delete()

        // Clear user's groupId
        try await db.collection("users").document(userId).updateData([
            "groupId": FieldValue.delete()
        ])

        // Delete all members（グループ削除後に孤立ドキュメントとして削除）
        let membersSnapshot = try await db.collection("groups").document(groupId)
            .collection("members").getDocuments()
        for member in membersSnapshot.documents {
            try await member.reference.delete()
        }
    }
}

enum GroupError: LocalizedError {
    case notAuthenticated
    case alreadyInGroup
    case notInGroup
    case invalidInviteCode
    case groupNotFound
    case groupFull
    case inviteCodeGenerationFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "サインインが必要です"
        case .alreadyInGroup: return "既にグループに所属しています"
        case .notInGroup: return "グループに所属していません"
        case .invalidInviteCode: return "招待コードが無効です"
        case .groupNotFound: return "グループが見つかりません"
        case .groupFull: return "グループの人数上限（10名）に達しています"
        case .inviteCodeGenerationFailed: return "招待コードの生成に失敗しました。再度お試しください"
        }
    }
}
