import XCTest
@testable import TowelApp

final class ProLimitsTests: XCTestCase {

    // MARK: - maxDailyAssessments

    func testMaxDailyAssessments_free() {
        XCTAssertEqual(ProLimits.maxDailyAssessments(isPro: false), 1)
    }

    func testMaxDailyAssessments_pro() {
        XCTAssertEqual(ProLimits.maxDailyAssessments(isPro: true), .max)
    }

    // MARK: - maxTowels

    func testMaxTowels_free() {
        XCTAssertEqual(ProLimits.maxTowels(isPro: false), 4)
    }

    func testMaxTowels_pro() {
        XCTAssertEqual(ProLimits.maxTowels(isPro: true), .max)
    }

    // MARK: - maxGroupMembers

    func testMaxGroupMembers_free() {
        XCTAssertEqual(ProLimits.maxGroupMembers(isPro: false), 3)
    }

    func testMaxGroupMembers_pro() {
        XCTAssertEqual(ProLimits.maxGroupMembers(isPro: true), 10)
    }

    // MARK: - maxVisibleConditionChecks

    func testMaxVisibleConditionChecks_free() {
        XCTAssertEqual(ProLimits.maxVisibleConditionChecks(isPro: false), 5)
    }

    func testMaxVisibleConditionChecks_pro() {
        XCTAssertEqual(ProLimits.maxVisibleConditionChecks(isPro: true), .max)
    }
}
