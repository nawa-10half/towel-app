import Foundation
import FirebaseFirestore

struct FamilyGroup: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String = ""
    var inviteCode: String = ""
    var createdBy: String = ""
    var memberCount: Int = 0
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
}

struct GroupMember: Codable, Identifiable {
    @DocumentID var id: String?  // userId
    var displayName: String?
    var role: String = "member"  // "owner" | "member"
    @ServerTimestamp var joinedAt: Date?
}
