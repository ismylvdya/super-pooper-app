import XCTest

/// Key user flows on the rendered test vault (`scripts/sim.sh load-vault` first).
/// They check the UI side; the file effects are checked by unit tests and by
/// `scripts/check-vault-after-ui-tests.sh`.
final class TodayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPResetState", "-SPSeedDemo"]
    }

    /// `-SPResetState` clears the day state, so the morning review opens by itself first;
    /// `-SPSeedDemo` brings back the demo calendar the event-linked tasks need.
    private func launch() {
        app.launch()
        let review = app.navigationBars["Morning review"]
        if review.waitForExistence(timeout: 8) {
            review.buttons["Done"].tap()
            XCTAssertTrue(review.waitForNonExistence(timeout: 5))
        }
    }

    /// Banners sit over the navigation bar for a few seconds; swipe them away like a user would.
    private func dismissBanners() {
        for _ in 0..<3 {
            let banner = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'problems' OR label BEGINSWITH 'Synced'")).firstMatch
            guard banner.waitForExistence(timeout: 2) else { return }
            banner.swipeUp()
        }
    }

    /// Timed items stay in place on the timeline after checking, so their state is easy to see.
    func testTapChecksHabitAndTask() {
        launch()
        let habit = app.buttons["check:Витамины 💊"]
        XCTAssertTrue(habit.waitForExistence(timeout: 10))
        habit.tap()
        XCTAssertTrue(app.buttons["check:Витамины 💊"].wait(for: \.label, toEqual: "Mark as not done", timeout: 5))

        let task = app.buttons["check:Подготовить вопросы папе"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        XCTAssertTrue(app.buttons["check:Подготовить вопросы папе"].wait(for: \.label, toEqual: "Mark as not done", timeout: 5))
    }

    func testLongPressHabitOffersPartiallyTwiceSkip() {
        launch()
        let row = app.buttons["title:Витамины 💊"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Partially"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Twice"].exists)
        XCTAssertTrue(app.buttons["Skip today"].exists)
        app.buttons["Partially"].tap()
    }

    func testTaskPageEditsHighPriority() {
        launch()
        let title = app.buttons["title:Распечатать вопросы"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        let high = app.switches["taskPage.high"]
        XCTAssertTrue(high.waitForExistence(timeout: 5))
        high.switches.firstMatch.tap()
        let switchedOn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: high)
        XCTAssertEqual(XCTWaiter().wait(for: [switchedOn], timeout: 5), .completed)
    }

    func testMorningReviewDragFixesManualOrder() {
        launch()
        let edit = app.buttons["today.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        dismissBanners()
        edit.tap()
        XCTAssertTrue(app.navigationBars["Morning review"].waitForExistence(timeout: 5))
        let first = app.cells.element(boundBy: 0)
        let third = app.cells.element(boundBy: 2)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let handle = first.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        handle.press(forDuration: 0.8, thenDragTo: third.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.8)))
        let reset = app.buttons["Reset to auto"]
        let manual = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: reset)
        XCTAssertEqual(XCTWaiter().wait(for: [manual], timeout: 5), .completed)
        reset.tap()
        let auto = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == false"), object: reset)
        XCTAssertEqual(XCTWaiter().wait(for: [auto], timeout: 5), .completed)
    }

    func testPullToRefreshShowsSyncBanner() {
        launch()
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        let banner = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Synced'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
    }
}
