import Foundation

enum AchievementCatalog {
    static let all: [AchievementDefinition] = personal + family + proOnly

    static let personal: [AchievementDefinition] = [
        .init(
            id: "first_exchange",
            category: .exchange,
            tier: .bronze,
            iconName: "badge_first_exchange",
            titleKey: "はじめの一歩",
            descriptionKey: "初めてアイテムを交換した",
            requirement: .exchangeCount(1),
            isProOnly: false,
            isGroupAchievement: false
        ),
        .init(
            id: "exchange_10",
            category: .exchange,
            tier: .bronze,
            iconName: "badge_exchange_10",
            titleKey: "交換10回",
            descriptionKey: "累計10回アイテムを交換した",
            requirement: .exchangeCount(10),
            isProOnly: false,
            isGroupAchievement: false
        ),
        .init(
            id: "exchange_50",
            category: .exchange,
            tier: .silver,
            iconName: "badge_exchange_50",
            titleKey: "交換50回",
            descriptionKey: "累計50回アイテムを交換した",
            requirement: .exchangeCount(50),
            isProOnly: false,
            isGroupAchievement: false
        ),
        .init(
            id: "exchange_100",
            category: .exchange,
            tier: .gold,
            iconName: "badge_exchange_100",
            titleKey: "交換100回",
            descriptionKey: "累計100回アイテムを交換した",
            requirement: .exchangeCount(100),
            isProOnly: false,
            isGroupAchievement: false
        ),
        .init(
            id: "first_diagnosis",
            category: .condition,
            tier: .bronze,
            iconName: "badge_first_diagnosis",
            titleKey: "初診断",
            descriptionKey: "初めて状態診断を行った",
            requirement: .conditionCheckCount(1),
            isProOnly: false,
            isGroupAchievement: false
        ),
        .init(
            id: "diagnosis_20",
            category: .condition,
            tier: .silver,
            iconName: "badge_diagnosis_20",
            titleKey: "診断マスター",
            descriptionKey: "累計20回状態診断を行った",
            requirement: .conditionCheckCount(20),
            isProOnly: false,
            isGroupAchievement: false
        ),
        .init(
            id: "full_house",
            category: .condition,
            tier: .silver,
            iconName: "badge_full_house",
            titleKey: "フルハウス",
            descriptionKey: "登録中のすべてのアイテムを診断済み",
            requirement: .allTowelsChecked,
            isProOnly: false,
            isGroupAchievement: false
        ),
        .init(
            id: "family_member",
            category: .group,
            tier: .bronze,
            iconName: "badge_family_member",
            titleKey: "家族の一員",
            descriptionKey: "家族グループに参加した",
            requirement: .firstGroupJoin,
            isProOnly: false,
            isGroupAchievement: false
        ),
        .init(
            id: "family_builder",
            category: .group,
            tier: .bronze,
            iconName: "badge_family_builder",
            titleKey: "家族の家主",
            descriptionKey: "家族グループを作成した",
            requirement: .firstGroupCreate,
            isProOnly: false,
            isGroupAchievement: false
        )
    ]

    static let family: [AchievementDefinition] = [
        .init(
            id: "family_exchange_50",
            category: .group,
            tier: .silver,
            iconName: "badge_family_exchange_50",
            titleKey: "家族で交換50回",
            descriptionKey: "家族全体で累計50回アイテムを交換した",
            requirement: .groupExchangeCount(50),
            isProOnly: false,
            isGroupAchievement: true
        ),
        .init(
            id: "family_exchange_200",
            category: .group,
            tier: .gold,
            iconName: "badge_family_exchange_200",
            titleKey: "家族で交換200回",
            descriptionKey: "家族全体で累計200回アイテムを交換した",
            requirement: .groupExchangeCount(200),
            isProOnly: false,
            isGroupAchievement: true
        ),
        .init(
            id: "family_all_active",
            category: .group,
            tier: .silver,
            iconName: "badge_family_all_active",
            titleKey: "全員参加",
            descriptionKey: "家族の全メンバーが1回以上交換した",
            requirement: .groupAllMembersActive,
            isProOnly: false,
            isGroupAchievement: true
        )
    ]

    static let proOnly: [AchievementDefinition] = [
        .init(
            id: "pro_supporter",
            category: .milestone,
            tier: .gold,
            iconName: "badge_pro_supporter",
            titleKey: "Proサポーター",
            descriptionKey: "Proプランを購入した",
            requirement: .proPurchase,
            isProOnly: true,
            isGroupAchievement: false
        ),
        .init(
            id: "clean_freak",
            category: .condition,
            tier: .gold,
            iconName: "badge_clean_freak",
            titleKey: "きれい好き",
            descriptionKey: "診断20回以上で平均スコア60以上を達成",
            requirement: .averageScore(min: 60, minChecks: 20),
            isProOnly: true,
            isGroupAchievement: false
        )
    ]

    static func definition(for id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }
}
