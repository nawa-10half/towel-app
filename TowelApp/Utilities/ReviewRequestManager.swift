import Foundation

struct ReviewRequestManager {
    static let exchangeCountKey = "exchangeRecordCount"
    static let reviewMilestones: Set<Int> = [3, 10]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Increments the exchange count and returns true if a review should be requested.
    mutating func recordExchangeAndCheckReview() -> Bool {
        let count = defaults.integer(forKey: Self.exchangeCountKey) + 1
        defaults.set(count, forKey: Self.exchangeCountKey)
        return Self.reviewMilestones.contains(count)
    }
}
