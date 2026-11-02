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

    /// The arrows next to the day's name change the day (the next one is Tomorrow, the one after it is named by its date
    /// and weekday, the one before today Yesterday) and stay where they are; the Today tab brings back today.
    func testArrowsChangeTheDayAndTheTodayTabBringsItBack() {
        launch()
        dismissBanners()
        let day = app.buttons["today.day"]
        XCTAssertEqual(day.label, "Today")
        let next = app.buttons["today.nextDay"]
        let previous = app.buttons["today.previousDay"]
        let arrows = (next.frame, previous.frame)
        let named = { (name: String) in NSPredicate(format: "identifier == 'today.day' AND label == %@", name) }
        let date = NSPredicate(format: "identifier == 'today.day' AND label MATCHES '^[0-9]{1,2} [A-Za-z]{3} • [A-Za-z]{3}$'")
        // Bar buttons refuse the accessibility "scroll to visible" step: tap by coordinate.
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(named("Tomorrow")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(next.frame, arrows.0, "the arrows do not move with the name")
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(date).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(next.frame, arrows.0)
        XCTAssertEqual(previous.frame, arrows.1)
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons.matching(named("Today")).firstMatch.waitForExistence(timeout: 5))
        previous.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(named("Yesterday")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(previous.frame, arrows.1)
        XCTAssertEqual(next.frame, arrows.0)
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
        let date = NSPredicate(format: "identifier == 'today.day' AND label IN {'Tomorrow', 'Yesterday'}")
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
        XCTAssertEqual(edit.label, "Morning review", "the review sheet is named Morning review, its list stays Soon")
        dismissBanners()
        edit.tap()
        XCTAssertTrue(app.navigationBars["Morning review"].waitForExistence(timeout: 5))
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

    /// A pool row dragged up onto the row above takes its place (.21800): the drag carries the row's own plate and leaves
    /// a gap in the pool; what it looks like mid-drag only a screenshot shows, the new order is checked here.
    func testAPoolRowDraggedUpTakesThePlaceAbove() {
        // "Обновить резюме" is due this Sunday: on that day it is in the pool whatever day of the week the run is on.
        app.launchArguments += ["-SPToday", TestVaultWeek.date(.sunday)]
        launch()
        dismissBanners()
        // Rows no other test marks or moves, so the suite's order does not matter.
        let resume = app.buttons["title:Обновить резюме"]
        let above = app.buttons["title:Неизвестное правило"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10) && above.waitForExistence(timeout: 5))
        XCTAssertLessThan(above.frame.midY, resume.frame.midY)
        resume.press(forDuration: 1.2, thenDragTo: above, withVelocity: .slow, thenHoldForDuration: 0.5)
        expect(resume, toBe: { $0.frame.midY < above.frame.midY }, "it stands above the row it was dropped on")
    }

    /// On the pages, a row dragged onto the edge of the other page turns to it. A habit without reminder times is
    /// dragged: the timeline does not take it, so letting go there changes nothing.
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

    /// On the pages, the day's name turns back to the pool; the Today tab turns back to the pool and to today's date, also
    /// from a page opened further in.
    func testTheDayNameAndTheTodayTabGoBackToTodaysPool() {
        app.launchArguments += ["-SPArrangement", "paged"]
        launch()
        dismissBanners()
        let edge = app.descendants(matching: .any)["today.pageEdge"]
        XCTAssertTrue(edge.waitForExistence(timeout: 10))
        let onPool = NSPredicate(format: "label == 'Show the timeline'")
        let onTimeline = NSPredicate(format: "label == 'Show the pool'")
        let wait = { (predicate: NSPredicate) in
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: edge)], timeout: 5)
        }
        edge.tap()
        XCTAssertEqual(wait(onTimeline), .completed)
        app.buttons["today.day"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(wait(onPool), .completed, "the day's name turns back to the pool")

        edge.tap()
        XCTAssertEqual(wait(onTimeline), .completed)
        app.buttons["today.nextDay"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let tomorrow = NSPredicate(format: "identifier == 'today.day' AND label == 'Tomorrow'")
        XCTAssertTrue(app.buttons.matching(tomorrow).firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["Habits"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertEqual(wait(onPool), .completed, "the Today tab turns back to the pool")
        XCTAssertEqual(app.buttons["today.day"].label, "Today", "and to today")

        let row = app.buttons["title:Выпить воды 💧"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertFalse(app.buttons["today.day"].waitForExistence(timeout: 3), "the habit's page is open")
        app.tabBars.buttons["Habits"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["today.day"].waitForExistence(timeout: 5), "back on Today's first page")
        XCTAssertEqual(wait(onPool), .completed)
    }

    /// A habit's block dragged from the timeline into the pool stands in the pool today, and dragged back from the pool it
    /// is on the timeline again (.3267). Side by side, both columns are in sight. The note keeps its time: no write
    /// (`check-vault-after-ui-tests.sh`); the notifications are covered by unit tests.
    func testAHabitBlockGoesToThePoolAndBackForToday() {
        app.launchArguments += ["-SPArrangement", "sideBySide"]
        launch()
        dismissBanners()
        let walk = app.buttons["title:Прогулка 🚶"]
        let now = app.buttons["title:Подготовить вопросы папе"]
        let pool = app.buttons["title:Утро — зарядка 🤸"]
        XCTAssertTrue(walk.waitForExistence(timeout: 10))
        XCTAssertTrue(now.waitForExistence(timeout: 5) && pool.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(walk.frame.midX, pool.frame.maxX, "the 14:00 block is on the timeline")

        walk.press(forDuration: 1.2, thenDragTo: pool, withVelocity: .slow, thenHoldForDuration: 0.5)
        expect(walk, toBe: { $0.frame.midX < now.frame.minX }, "in the pool")

        walk.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.2, thenDragTo: now.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 5)), withVelocity: .slow,
                   thenHoldForDuration: 0.5)
        expect(walk, toBe: { $0.frame.midX > pool.frame.maxX }, "back on the timeline")
    }

    private func expect(_ element: XCUIElement, toBe condition: @escaping (XCUIElement) -> Bool, _ message: String) {
        let met = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in element.exists && condition(element) }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [met], timeout: 5), .completed, message)
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
