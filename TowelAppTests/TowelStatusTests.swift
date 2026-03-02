import XCTest
@testable import TowelApp

final class TowelStatusTests: XCTestCase {

    // MARK: - status

    func testStatus_freshTowel_returnsOk() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let towel = makeTowel(lastExchangedAt: yesterday, intervalDays: 7)

        XCTAssertEqual(towel.status, .ok)
    }

    func testStatus_nearDeadline_returnsSoon() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        let towel = makeTowel(lastExchangedAt: twoDaysAgo, intervalDays: 3)

        XCTAssertEqual(towel.status, .soon)
    }

    func testStatus_exactDeadline_returnsSoon() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        let towel = makeTowel(lastExchangedAt: threeDaysAgo, intervalDays: 3)

        XCTAssertEqual(towel.status, .soon)
    }

    func testStatus_pastDeadline_returnsOverdue() {
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let towel = makeTowel(lastExchangedAt: fiveDaysAgo, intervalDays: 3)

        XCTAssertEqual(towel.status, .overdue)
    }

    // MARK: - daysSinceLastExchange

    func testDaysSinceLastExchange_withLastExchangedAt() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        let towel = makeTowel(lastExchangedAt: threeDaysAgo, intervalDays: 7)

        XCTAssertEqual(towel.daysSinceLastExchange, 3)
    }

    func testDaysSinceLastExchange_nilLastExchangedAt_usesCreatedAt() {
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        let towel = makeTowel(lastExchangedAt: nil, createdAt: fiveDaysAgo, intervalDays: 7)

        XCTAssertEqual(towel.daysSinceLastExchange, 5)
    }

    // MARK: - nextExchangeDate

    func testNextExchangeDate_calculatesCorrectly() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let towel = makeTowel(lastExchangedAt: yesterday, intervalDays: 7)

        let expected = Calendar.current.date(byAdding: .day, value: 7, to: yesterday)!
        let diffSeconds = abs(towel.nextExchangeDate.timeIntervalSince(expected))
        XCTAssertLessThan(diffSeconds, 1, "nextExchangeDate should be 7 days after lastExchangedAt")
    }

    func testNextExchangeDate_nilLastExchangedAt_usesCreatedAt() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let towel = makeTowel(lastExchangedAt: nil, createdAt: yesterday, intervalDays: 3)

        let expected = Calendar.current.date(byAdding: .day, value: 3, to: yesterday)!
        let diffSeconds = abs(towel.nextExchangeDate.timeIntervalSince(expected))
        XCTAssertLessThan(diffSeconds, 1, "nextExchangeDate should be 3 days after createdAt")
    }

    // MARK: - Helpers

    private func makeTowel(
        lastExchangedAt: Date?,
        createdAt: Date? = nil,
        intervalDays: Int
    ) -> Towel {
        var towel = Towel(
            name: "テスト用タオル",
            location: "テスト",
            exchangeIntervalDays: intervalDays,
            lastExchangedAt: lastExchangedAt
        )
        if let createdAt {
            towel.createdAt = createdAt
        }
        return towel
    }
}
