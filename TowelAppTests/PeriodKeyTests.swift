import XCTest
@testable import TowelApp

final class PeriodKeyTests: XCTestCase {

    func testPeriodKey_referenceDate_returnsPeriod0() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        XCTAssertEqual(PeriodKey.current(now: date), "period-0")
    }

    func testPeriodKey_day3_returnsPeriod1() {
        let date = makeDate(year: 2026, month: 1, day: 4)
        XCTAssertEqual(PeriodKey.current(now: date), "period-1")
    }

    func testPeriodKey_day2_stillPeriod0() {
        let date = makeDate(year: 2026, month: 1, day: 3)
        XCTAssertEqual(PeriodKey.current(now: date), "period-0")
    }

    func testPeriodKey_day6_returnsPeriod2() {
        let date = makeDate(year: 2026, month: 1, day: 7)
        XCTAssertEqual(PeriodKey.current(now: date), "period-2")
    }

    func testPeriodKey_beforeReference_returnsNegativePeriod() {
        let date = makeDate(year: 2025, month: 12, day: 31)
        XCTAssertEqual(PeriodKey.current(now: date), "period-0")
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
