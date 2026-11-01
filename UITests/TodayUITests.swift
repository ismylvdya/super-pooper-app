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

    /// The arrows next to the day's name change the day (another day is named by its date) and stay where they are;
    /// the Today tab brings back today.
    func testArrowsChangeTheDayAndTheTodayTabBringsItBack() {
        launch()
        dismissBanners()
        let day = app.buttons["today.day"]
        XCTAssertEqual(day.label, "Today")
        let next = app.buttons["today.nextDay"]
        let previous = app.buttons["today.previousDay"]
        let arrows = (next.frame, previous.frame)
        let date = NSPredicate(format: "identifier == 'today.day' AND label MATCHES '^[0-9]{1,2} [A-Za-z]{3}$'")
        // Bar buttons refuse the accessibility "scroll to visible" step: tap by coordinate.
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(date).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(next.frame, arrows.0, "the arrows do not move with the name")
        XCTAssertEqual(previous.frame, arrows.1)
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == 'today.day' AND label == 'Today'")).firstMatch
            .waitForExistence(timeout: 5))
        previous.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(date).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(previous.frame, arrows.1)
    }

    /// The arrows take taps across the whole bar height (`size.dayArrowTarget`, 44 pt), on the room around the glyph and
    /// on the gap to the name: taps in the far corners of an arrow's area still turn the day.
    func testTheDayArrowsAreEasyToHit() {
        launch()
        dismissBanners()
        let next = app.buttons["today.nextDay"]
        let previous = app.buttons["today.previousDay"]
        for arrow in [next, previous] {
            XCTAssertGreaterThanOrEqual(arrow.frame.height.rounded(), 44, arrow.identifier)
            XCTAssertGreaterThan(arrow.frame.width, app.buttons["today.day"].frame.height / 2, arrow.identifier)
        }
        let date = NSPredicate(format: "identifier == 'today.day' AND label MATCHES '^[0-9]{1,2} [A-Za-z]{3}$'")
        let today = NSPredicate(format: "identifier == 'today.day' AND label == 'Today'")
        let corners = [(next, CGVector(dx: 0.95, dy: 0.08)), (next, CGVector(dx: 0.05, dy: 0.92)),
                       (previous, CGVector(dx: 0.05, dy: 0.08)), (previous, CGVector(dx: 0.95, dy: 0.92))]
        for (arrow, corner) in corners {
            arrow.coordinate(withNormalizedOffset: corner).tap()
            XCTAssertTrue(app.buttons.matching(date).firstMatch.waitForExistence(timeout: 5), "\(arrow.identifier) at \(corner)")
            app.tabBars.buttons["Today"].tap()
            XCTAssertTrue(app.buttons.matching(today).firstMatch.waitForExistence(timeout: 5))
        }
    }

    /// Pool rows have no checkboxes: a long press offers Done, and the done task leaves the pool.
    func testLongPressMarksATaskDone() {
        launch()
        dismissBanners()
        let title = app.buttons["title:Оплатить интернет"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.press(forDuration: 1.2)
        let done = app.buttons["DONE"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        expectLeftThePool(title)
    }

    /// Done items leave the pool.
    private func expectLeftThePool(_ row: XCUIElement) {
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false OR hittable == false"), object: row)
        XCTAssertEqual(XCTWaiter().wait(for: [moved], timeout: 5), .completed)
    }

    /// "Выпить воды" is the first pool row (the morning routine goes first), so it is always on screen. A habit's menu
    /// in Today has Done and Skip today; Partially and Twice are only on the Habits tab (D-047).
    func testLongPressHabitOffersDoneAndSkip() {
        launch()
        dismissBanners()
        let row = app.buttons["title:Выпить воды 💧"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.2)
        let done = app.buttons["DONE"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Skip today"].exists)
        XCTAssertFalse(app.buttons["Partially"].exists)
        XCTAssertFalse(app.buttons["Twice"].exists)
        done.tap()
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

    /// On the pages, a row dragged onto the edge of the other page turns to it. A habit is dragged: the timeline does not
    /// take habits, so letting go there changes nothing.
    func testDraggingOntoThePageEdgeTurnsThePage() {
        app.launchArguments += ["-SPArrangement", "paged"]
        launch()
        dismissBanners()
        let edge = app.descendants(matching: .any)["today.pageEdge"]
        XCTAssertTrue(edge.waitForExistence(timeout: 10))
        XCTAssertEqual(edge.label, "Show the timeline")
        let row = app.buttons["title:Выпить воды 💧"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.2, thenDragTo: edge, withVelocity: .slow, thenHoldForDuration: 1)
        let turned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Show the pool'"), object: edge)
        XCTAssertEqual(XCTWaiter().wait(for: [turned], timeout: 5), .completed, "the pages turned to the timeline")
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
