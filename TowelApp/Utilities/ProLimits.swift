import Foundation

enum ProLimits {
    static func maxDailyAssessments(isPro: Bool) -> Int {
        isPro ? .max : 1
    }

    static func maxTowels(isPro: Bool) -> Int {
        isPro ? .max : 4
    }

    static func maxGroupMembers(isPro: Bool) -> Int {
        isPro ? 10 : 3
    }

    static func maxVisibleConditionChecks(isPro: Bool) -> Int {
        isPro ? .max : 5
    }
}
