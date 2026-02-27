import XCTest
@testable import TowelApp

final class ReviewRequestManagerTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ReviewRequestManagerTests")!
        defaults.removeObject(forKey: ReviewRequestManager.exchangeCountKey)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "ReviewRequestManagerTests")
        super.tearDown()
    }

    // MARK: - Milestone detection

    func testFirstExchange_doesNotTriggerReview() {
        var manager = ReviewRequestManager(defaults: defaults)
        XCTAssertFalse(manager.recordExchangeAndCheckReview())
    }

    func testSecondExchange_doesNotTriggerReview() {
        var manager = ReviewRequestManager(defaults: defaults)
        _ = manager.recordExchangeAndCheckReview() // 1
        XCTAssertFalse(manager.recordExchangeAndCheckReview()) // 2
    }

    func testThirdExchange_triggersReview() {
        var manager = ReviewRequestManager(defaults: defaults)
        _ = manager.recordExchangeAndCheckReview() // 1
        _ = manager.recordExchangeAndCheckReview() // 2
        XCTAssertTrue(manager.recordExchangeAndCheckReview()) // 3
    }

    func testFourthExchange_doesNotTriggerReview() {
        var manager = ReviewRequestManager(defaults: defaults)
        for _ in 1...3 { _ = manager.recordExchangeAndCheckReview() }
        XCTAssertFalse(manager.recordExchangeAndCheckReview()) // 4
    }

    func testTenthExchange_triggersReview() {
        var manager = ReviewRequestManager(defaults: defaults)
        for _ in 1...9 { _ = manager.recordExchangeAndCheckReview() }
        XCTAssertTrue(manager.recordExchangeAndCheckReview()) // 10
    }

    func testEleventhExchange_doesNotTriggerReview() {
        var manager = ReviewRequestManager(defaults: defaults)
        for _ in 1...10 { _ = manager.recordExchangeAndCheckReview() }
        XCTAssertFalse(manager.recordExchangeAndCheckReview()) // 11
    }

    // MARK: - Counter persistence

    func testCounter_persistsAcrossInstances() {
        var manager1 = ReviewRequestManager(defaults: defaults)
        _ = manager1.recordExchangeAndCheckReview() // 1
        _ = manager1.recordExchangeAndCheckReview() // 2

        // New instance, same defaults
        var manager2 = ReviewRequestManager(defaults: defaults)
        XCTAssertTrue(manager2.recordExchangeAndCheckReview()) // 3
    }

    func testCounter_incrementsCorrectly() {
        var manager = ReviewRequestManager(defaults: defaults)
        for _ in 1...5 { _ = manager.recordExchangeAndCheckReview() }
        XCTAssertEqual(defaults.integer(forKey: ReviewRequestManager.exchangeCountKey), 5)
    }
}
