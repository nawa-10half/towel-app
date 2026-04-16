import Foundation
import SwiftUI
import FirebaseFirestore

enum AchievementCategory: String, Codable {
    case exchange
    case condition
    case group
    case milestone
}

enum AchievementTier: Int, Codable, Comparable {
    case bronze = 1
    case silver = 2
    case gold = 3

    static func < (lhs: AchievementTier, rhs: AchievementTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var color: Color {
        switch self {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        }
    }
}

enum AchievementRequirement {
    case exchangeCount(Int)
    case conditionCheckCount(Int)
    case averageScore(min: Double, minChecks: Int)
    case allTowelsChecked
    case firstGroupJoin
    case firstGroupCreate
    case proPurchase
    case groupExchangeCount(Int)
    case groupAllMembersActive
}

struct AchievementDefinition: Identifiable, Hashable {
    let id: String
    let category: AchievementCategory
    let tier: AchievementTier
    let iconName: String
    let titleKey: String.LocalizationValue
    let descriptionKey: String.LocalizationValue
    let requirement: AchievementRequirement
    let isProOnly: Bool
    let isGroupAchievement: Bool

    var title: String { String(localized: titleKey) }
    var description: String { String(localized: descriptionKey) }

    static func == (lhs: AchievementDefinition, rhs: AchievementDefinition) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct UnlockedAchievement: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    @ServerTimestamp var unlockedAt: Date?
    var seen: Bool = false
    var tier: String

    enum CodingKeys: String, CodingKey {
        case id
        case unlockedAt
        case seen
        case tier
    }
}

struct GroupUnlockedAchievement: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    @ServerTimestamp var unlockedAt: Date?
    var unlockedBy: String

    enum CodingKeys: String, CodingKey {
        case id
        case unlockedAt
        case unlockedBy
    }
}
