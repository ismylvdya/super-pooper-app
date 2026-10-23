import XCTest

/// Key user flows on the rendered test vault (`scripts/sim.sh load-vault` first).
/// They check the UI side; the file effects are checked by unit tests and by
/// `scripts/check-vault-after-ui-tests.sh`.
final class TodayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPResetState", "-SPSeedDemo",
                               "-SPOpen", "superpooper://today"]
    }

    /// `-SPResetState` clears the day state; opening a link keeps the morning review from opening by
    /// itself. `-SPSeedDemo` brings back the demo calendar the event-linked tasks need.
    private func launch() {
        app.launch()
        XCTAssertTrue(app.buttons["today.review"].waitForExistence(timeout: 10))
    }

    /// Banners sit over the navigation bar for a few seconds; swipe them away like a user would.
    private func dismissBanners() {
        for _ in 0..<3 {
            let banner = app.descendants(matching: .any)["banner"]
            guard banner.waitForExistence(timeout: 2) else { return }
            banner.swipeUp()
            XCTAssertTrue(banner.waitForNonExistence(timeout: 3), "a swipe up must dismiss the banner")
        }
    }

    /// Pool rows have no checkboxes: a long press offers Done, and the done task moves to the end.
    func testLongPressMarksATaskDone() {
        launch()
        dismissBanners()
        let title = app.buttons["title:Оплатить интернет"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.press(forDuration: 1.2)
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        expectMovedToTheEnd(title)
    }

    /// Done items go to the end of the pool, below the visible rows.
    private func expectMovedToTheEnd(_ row: XCUIElement) {
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false OR hittable == false"), object: row)
        XCTAssertEqual(XCTWaiter().wait(for: [moved], timeout: 5), .completed)
    }

    /// "Выпить воды" is the first pool row (habits without time go first), so it is always on screen.
    func testLongPressHabitOffersPartiallyTwiceSkip() {
        launch()
        dismissBanners()
        let row = app.buttons["title:Выпить воды 💧"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Partially"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Twice"].exists)
        XCTAssertTrue(app.buttons["Skip today"].exists)
        app.buttons["Partially"].tap()
        expectMovedToTheEnd(row)
    }

    func testTaskPageEditsHighPriority() {
        launch()
        dismissBanners()
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
        let edit = app.buttons["today.review"]
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
        dismissBanners()
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.95)))
        let banner = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Synced'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
    }
}
