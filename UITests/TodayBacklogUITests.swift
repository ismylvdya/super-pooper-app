import XCTest

/// The backlog pages left of the pool on Tasks (`scripts/sim.sh load-vault` first): opened by pulling the pool right,
/// forgotten by another tab, and a drop target for pool rows. Runs after the classes that count on today's pool as the
/// vault has it: the drop here keeps a task out of today (day state only, the next launch with `-SPResetState` clears it).
final class TodayBacklogUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPResetState", "-SPSeedDemo",
                               "-SPOpen", "superpooper://today"]
    }

    private func launch() {
        app.launch()
        XCTAssertTrue(app.buttons["today.lists"].waitForExistence(timeout: 10))
    }

    private func dismissBanners() {
        app.dismissBanners()
    }

    private func expect(_ element: XCUIElement, toBe condition: @escaping (XCUIElement) -> Bool, _ message: String) {
        let met = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in element.exists && condition(element) }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [met], timeout: 5), .completed, message)
    }

    /// The backlog pages open one by one: the pool pulled right past its edge opens Soon, pulled again Half year, each with
    /// its list's title in the bar instead of the day's name; a swipe goes back through them.
    func testPullingThePoolRightOpensSoonThenHalfYear() {
        app.launchArguments += ["-SPArrangement", "paged"]
        launch()
        dismissBanners()
        let title = app.staticTexts["today.listTitle"]
        pullRight()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Soon")
        XCTAssertFalse(app.buttons["today.day"].exists, "a backlog page has no day arrows")
        pullRight()
        expect(title, toBe: { $0.label == "Nearest months" }, "Half year opened next")
        app.swipeLeft()
        expect(title, toBe: { $0.label == "Soon" }, "back to Soon")
        app.swipeLeft()
        XCTAssertTrue(app.buttons["today.day"].waitForExistence(timeout: 5), "back on the pool")
        XCTAssertEqual(app.buttons["today.day"].label, "Today")
    }

    /// Another tab forgets the backlog pages: back on Tasks the pool shows and nothing stands left of it.
    func testAnotherTabForgetsTheLeftPages() {
        app.launchArguments += ["-SPArrangement", "paged"]
        launch()
        dismissBanners()
        pullRight()
        XCTAssertTrue(app.staticTexts["today.listTitle"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Habits"].tap()
        app.tabBars.buttons["Tasks"].tap()
        XCTAssertTrue(app.buttons["today.day"].waitForExistence(timeout: 5))
        let soonEdge = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'today.pageEdge' AND label == 'Show Soon'")).firstMatch
        XCTAssertFalse(soonEdge.waitForExistence(timeout: 2), "no Soon page left of the pool")
    }

    func testASidewaysPanKeepsTheBacklogAtItsVerticalScrollPosition() {
        app.launchArguments += ["-SPArrangement", "paged"]
        launch()
        dismissBanners()
        pullRight()
        let backlog = app.descendants(matching: .any)["backlog.thisWeek"].firstMatch
        let row = backlog.staticTexts["Записать идеи"].firstMatch
        let screen = app.frame
        let onScreen = { (page: XCUIElement) in
            screen.contains(CGPoint(x: page.frame.midX, y: screen.midY))
        }
        expect(backlog, toBe: onScreen, "Soon opened")
        XCTAssertTrue(row.exists)
        let initialY = row.frame.minY

        pan(from: CGVector(dx: 0.82, dy: 0.56), to: CGVector(dx: 0.14, dy: 0.40))
        let turned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !backlog.exists || !onScreen(backlog) }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [turned], timeout: 5), .completed, "the mostly horizontal pan turned the page")
        app.swipeRight()
        expect(backlog, toBe: onScreen, "back to Soon")
        XCTAssertTrue(row.exists)
        XCTAssertEqual(row.frame.minY, initialY, accuracy: 1, "turning the page did not scroll the backlog")

        pan(from: CGVector(dx: 0.56, dy: 0.72), to: CGVector(dx: 0.49, dy: 0.36))
        XCTAssertTrue(!row.exists || row.frame.minY < initialY - 1, "the backlog scrolled vertically")
        XCTAssertTrue(backlog.exists && onScreen(backlog), "the mostly vertical pan stayed on Soon")
    }

    private func pan(from start: CGVector, to end: CGVector) {
        app.coordinate(withNormalizedOffset: start).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: end))
    }

    /// A pool row dragged onto the edge of the Soon page turns to it and, let go there, is listed in Soon: Not today, it
    /// has left today's pool (day state only, the note stays as it is).
    func testAPoolRowDraggedOntoSoonLeavesTheDay() {
        app.launchArguments += ["-SPArrangement", "paged"]
        launch()
        dismissBanners()
        pullRight()
        XCTAssertTrue(app.staticTexts["today.listTitle"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.buttons["today.day"].waitForExistence(timeout: 5))
        // A row near the top, so no scrolling comes before the drag.
        let row = app.buttons["title:Позвонить в банк"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let edge = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'today.pageEdge' AND label == 'Show Soon'")).firstMatch
        XCTAssertTrue(edge.exists)
        // The edge is the screen's margin beside the pool (Soon shows nothing of itself there). The way there goes well down
        // too: the long-press menu turns into a drag only once the finger has moved far enough from it, and a drag
        // almost along the row sometimes leaves the menu open in the simulator.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 1.2, thenDragTo: edge.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)),
                   withVelocity: .slow, thenHoldForDuration: 1)
        let title = app.staticTexts["today.listTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "the pages turned to Soon")
        let listed = app.descendants(matching: .any)["backlog.thisWeek"].buttons["title:Позвонить в банк"]
        XCTAssertTrue(listed.waitForExistence(timeout: 5), "listed in Soon")
    }

    /// From the pool's left part to the right: the first page is pulled past its edge.
    private func pullRight() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.55))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.55)),
                    withVelocity: .default, thenHoldForDuration: 0.2)
    }
}
