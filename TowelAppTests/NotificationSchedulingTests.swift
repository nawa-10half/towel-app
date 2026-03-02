import XCTest
@testable import TowelApp

final class NotificationSchedulingTests: XCTestCase {

    // MARK: - nextNotificationDateComponents

    func testNextNotification_beforeConfiguredTime_returnsToday() {
        // 現在 08:00、設定時刻 20:00 → 今日の 20:00
        let now = date(2026, 2, 26, hour: 8, minute: 0)
        let result = NotificationService.nextNotificationDateComponents(hour: 20, minute: 0, now: now)

        XCTAssertEqual(result.year, 2026)
        XCTAssertEqual(result.month, 2)
        XCTAssertEqual(result.day, 26)
        XCTAssertEqual(result.hour, 20)
        XCTAssertEqual(result.minute, 0)
    }

    func testNextNotification_afterConfiguredTime_returnsTomorrow() {
        // 現在 21:00、設定時刻 08:00 → 明日の 08:00
        let now = date(2026, 2, 26, hour: 21, minute: 0)
        let result = NotificationService.nextNotificationDateComponents(hour: 8, minute: 0, now: now)

        XCTAssertEqual(result.year, 2026)
        XCTAssertEqual(result.month, 2)
        XCTAssertEqual(result.day, 27)
        XCTAssertEqual(result.hour, 8)
        XCTAssertEqual(result.minute, 0)
    }

    func testNextNotification_exactlyAtConfiguredTime_returnsTomorrow() {
        // 現在 08:00 ちょうど、設定時刻 08:00 → 過ぎたと判定して明日
        let now = date(2026, 2, 26, hour: 8, minute: 0)
        let result = NotificationService.nextNotificationDateComponents(hour: 8, minute: 0, now: now)

        XCTAssertEqual(result.day, 27)
        XCTAssertEqual(result.hour, 8)
    }

    func testNextNotification_monthBoundary_rollsToNextMonth() {
        // 2月28日 23:00、設定時刻 08:00 → 3月1日 (2026年は非閏年)
        let now = date(2026, 2, 28, hour: 23, minute: 0)
        let result = NotificationService.nextNotificationDateComponents(hour: 8, minute: 0, now: now)

        XCTAssertEqual(result.month, 3)
        XCTAssertEqual(result.day, 1)
        XCTAssertEqual(result.hour, 8)
    }

    func testNextNotification_yearBoundary_rollsToNextYear() {
        // 12月31日 23:00、設定時刻 08:00 → 翌年1月1日
        let now = date(2026, 12, 31, hour: 23, minute: 0)
        let result = NotificationService.nextNotificationDateComponents(hour: 8, minute: 0, now: now)

        XCTAssertEqual(result.year, 2027)
        XCTAssertEqual(result.month, 1)
        XCTAssertEqual(result.day, 1)
    }

    // MARK: - Overdue trigger scheduling logic

    func testOverdueTowel_getsNextNotificationTime() {
        // 3日前に交換、交換間隔1日 → 2日前が期限 → overdue
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now)!
        let towel = makeTowel(lastExchangedAt: threeDaysAgo, intervalDays: 1)

        XCTAssertEqual(towel.status, .overdue)

        // overdue なので次の通知時刻が返るはず (通知ロジックは固定日時でテスト)
        let now = date(2026, 2, 26, hour: 10, minute: 0)
        let result = NotificationService.nextNotificationDateComponents(hour: 8, minute: 0, now: now)
        // 10:00 に設定時刻 08:00 は過ぎている → 明日
        XCTAssertEqual(result.day, 27)
    }

    func testFutureTowel_isNotOverdue() {
        // 今日交換、交換間隔7日 → 7日後が期限 → ok
        let towel = makeTowel(lastExchangedAt: .now, intervalDays: 7)

        XCTAssertEqual(towel.status, .ok)
    }

    func testSoonTowel_isSoon() {
        // 昨日交換、交換間隔2日 → 明日が期限 → soon (remaining=1, <=1)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let towel = makeTowel(lastExchangedAt: yesterday, intervalDays: 2)

        XCTAssertEqual(towel.status, .soon)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)!
    }

    private func makeTowel(lastExchangedAt: Date, intervalDays: Int) -> Towel {
        Towel(
            name: "テスト用タオル",
            location: "キッチン",
            exchangeIntervalDays: intervalDays,
            lastExchangedAt: lastExchangedAt
        )
    }
}
