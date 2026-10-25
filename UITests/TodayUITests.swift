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

    private func dismissBanners() {
        app.dismissBanners()
    }

    /// The arrows next to the day's name change the day; the Today tab brings back today.
    func testArrowsChangeTheDayAndTheTodayTabBringsItBack() {
        launch()
        dismissBanners()
        let day = app.buttons["today.day"]
        XCTAssertEqual(day.label, "Today")
        // Bar buttons refuse the accessibility "scroll to visible" step: tap by coordinate.
        app.buttons["today.nextDay"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == 'today.day' AND label BEGINSWITH 'Tomorrow'")).firstMatch
            .waitForExistence(timeout: 5))
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == 'today.day' AND label == 'Today'")).firstMatch
            .waitForExistence(timeout: 5))
        app.buttons["today.previousDay"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == 'today.day' AND label BEGINSWITH 'Yesterday'")).firstMatch
            .waitForExistence(timeout: 5))
    }

    /// Pool rows have no checkboxes: a long press offers Done, and the done task leaves the pool.
    func testLongPressMarksATaskDone() {
        launch()
        dismissBanners()
        let title = app.buttons["title:Оплатить интернет"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.press(forDuration: 1.2)
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        expectLeftThePool(title)
    }

    /// Done items leave the pool.
    private func expectLeftThePool(_ row: XCUIElement) {
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false OR hittable == false"), object: row)
        XCTAssertEqual(XCTWaiter().wait(for: [moved], timeout: 5), .completed)
    }

    /// "Выпить воды" is the first pool row (the morning routine goes first), so it is always on screen.
    /// It is not a twice-a-day habit, so its menu has no Twice.
    func testLongPressHabitOffersPartiallyAndSkip() {
        launch()
        dismissBanners()
        let row = app.buttons["title:Выпить воды 💧"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Partially"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Twice"].exists)
        XCTAssertTrue(app.buttons["Skip today"].exists)
        app.buttons["Partially"].tap()
        expectLeftThePool(row)
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
        XCTAssertTrue(app.navigationBars["This week"].waitForExistence(timeout: 5))
        // Row 0 is the Morning header; the tasks start at row 1.
        let first = app.cells.element(boundBy: 1)
        let third = app.cells.element(boundBy: 3)
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
