import XCTest

/// Native swipes in the lists (.1237, .1471): to the right Done (Return in the Done list), to the left Delete after the
/// confirmation, or — in the archive and the trash — back. The files are checked by `scripts/check-vault-after-ui-tests.sh`.
final class SwipeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ link: String, today: String? = nil) {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPOpen", link]
        if let today { app.launchArguments += ["-SPToday", today] }
        app.launch()
    }

    /// The list row that shows `text`.
    private func row(_ text: String) -> XCUIElement {
        app.cells.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// The row that shows `text`, scrolled into view once the list is there (a lazy list lays out only what shows, and
    /// the tests before this one may have added rows above it).
    private func find(_ text: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10), file: file, line: line)
        app.dismissBanners()
        let found = row(text)
        app.scrollIntoView(found, file: file, line: line)
        return found
    }

    /// Drags the row part of the way, slowly: its swipe buttons show, and none runs by itself (a full swipe would).
    private func reveal(_ row: XCUIElement, right: Bool) {
        app.scrollIntoView(row)
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: right ? 0.15 : 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: (right ? 1 : -1) * row.frame.width * 0.4, dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// Shows the row's swipe buttons and presses one.
    private func swipe(_ row: XCUIElement, right: Bool, press action: String, file: StaticString = #filePath, line: UInt = #line) {
        reveal(row, right: right)
        let button = app.buttons["swipe.\(action)"]
        XCTAssertTrue(button.waitForExistence(timeout: 3), "swipe.\(action)", file: file, line: line)
        button.tap()
    }

    private func expectBanner(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let banner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'banner' AND label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "banner \(text)", file: file, line: line)
    }

    /// Habits: a swipe to the right marks today Done; a habit done once a day then has nothing left to swipe to.
    func testHabitsSwipeRightMarksDone() {
        launch("superpooper://habits")
        let habit = app.cells.containing(.button, identifier: "habit:Полить цветы 🌱").firstMatch
        XCTAssertTrue(habit.waitForExistence(timeout: 10))
        app.dismissBanners()
        swipe(habit, right: true, press: "done")
        XCTAssertTrue(app.buttons["swipe.done"].waitForNonExistence(timeout: 3))
        reveal(habit, right: true)
        XCTAssertFalse(app.buttons["swipe.done"].waitForExistence(timeout: 2), "the day is marked")
    }

    /// A list of the Lists tab: a swipe to the left puts the task in the trash at once, the banner offers Undo (.27143).
    func testListSwipeLeftDeletesAtOnceAndOffersUndo() {
        launch("superpooper://lists/waiting")
        let task = find("Ждать ответа от арендодателя")
        swipe(task, right: false, press: "delete")
        expectBanner("to trash")
        XCTAssertTrue(app.buttons["banner.undo"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists, "no confirmation")
        XCTAssertTrue(task.waitForNonExistence(timeout: 5))
    }

    /// A list of the Lists tab: a swipe to the right is Done (the task goes to the done folder).
    func testListSwipeRightIsDone() {
        launch("superpooper://lists/thisWeek")
        let task = find("Разобрать почту")
        swipe(task, right: true, press: "done")
        XCTAssertTrue(task.waitForNonExistence(timeout: 10), "a done task leaves the Soon list")
    }

    /// The Done list: a filed task returns to Soon from its menu (Return) and with a swipe to the right.
    func testDoneListReturnsFiledTasks() {
        launch("superpooper://lists/done")
        let old = find("Старая сделанная задача")
        old.press(forDuration: 1.2)
        let menuReturn = app.buttons["Return"]
        XCTAssertTrue(menuReturn.waitForExistence(timeout: 5), "the menu offers Return")
        menuReturn.tap()
        expectBanner("Старая сделанная задача")
        XCTAssertTrue(old.waitForNonExistence(timeout: 10))

        let milk = find("Купить молоко")
        swipe(milk, right: true, press: "returnFromDone")
        expectBanner("Купить молоко")
        XCTAssertTrue(milk.waitForNonExistence(timeout: 10))
    }

    /// Soon: to the left exactly one button, Not today for a task and Skip today for a habit (no Delete); to the right Done.
    func testSoonOffersOneButtonToTheLeftAndDoneToTheRight() {
        // "Сдать отчёт" is due this Friday: on that day it stands in Soon whatever day of the week the run is on.
        launch("superpooper://review", today: TestVaultWeek.date(.friday))
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))
        app.dismissBanners()
        let habit = app.cells.containing(.any, identifier: "review:Утро — зарядка 🤸").firstMatch
        app.scrollIntoView(habit)
        reveal(habit, right: false)
        XCTAssertTrue(app.buttons["swipe.skipToday"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["swipe.delete"].exists, "no Delete in Soon")
        XCTAssertFalse(app.buttons["swipe.notToday"].exists)
        reveal(habit, right: true)
        XCTAssertTrue(app.buttons["swipe.skipToday"].waitForNonExistence(timeout: 3))

        let task = find("Сдать отчёт")
        reveal(task, right: false)
        XCTAssertTrue(app.buttons["swipe.notToday"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["swipe.delete"].exists, "no Delete in Soon")
        XCTAssertFalse(app.buttons["swipe.skipToday"].exists)
        // A drag back closes the buttons; the next one shows the other side.
        reveal(task, right: true)
        XCTAssertTrue(app.buttons["swipe.notToday"].waitForNonExistence(timeout: 3))
        reveal(task, right: true)
        XCTAssertTrue(app.buttons["swipe.done"].waitForExistence(timeout: 3))
    }

    /// Morning review's Not today group swipes as the groups above: Done to the right, back to Today to the left.
    func testThePostponedGroupSwipesDoneRightAndTodayLeft() {
        launch("superpooper://review")
        let task = find("Оплатить интернет")
        swipe(task, right: false, press: "notToday")
        let waiting = app.descendants(matching: .any).matching(identifier: "review.notToday:Оплатить интернет").firstMatch
        app.scrollIntoView(waiting)
        reveal(waiting, right: true)
        XCTAssertTrue(app.buttons["swipe.done"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["swipe.backToToday"].exists)
        reveal(waiting, right: false)
        XCTAssertTrue(app.buttons["swipe.done"].waitForNonExistence(timeout: 3))
        swipe(waiting, right: false, press: "backToToday")
        XCTAssertTrue(waiting.waitForNonExistence(timeout: 10))
    }

    /// The archive: a swipe to the left brings an archived task back to Soon.
    func testArchiveSwipeLeftRestoresToSoon() {
        launch("superpooper://archive")
        let task = find("Архивная задача")
        swipe(task, right: false, press: "restoreThisWeek")
        XCTAssertTrue(task.waitForNonExistence(timeout: 10), "it leaves the archive")
    }

    /// The trash: a note deleted with a swipe comes back with a swipe to the left.
    func testTrashSwipeLeftRestores() {
        launch("superpooper://lists/thisWeek")
        let task = find("Связь на несуществующую")
        swipe(task, right: false, press: "delete")
        expectBanner("to trash")
        app.terminate()

        launch("superpooper://trash")
        let trashed = find("Связь на несуществующую")
        swipe(trashed, right: false, press: "restoreFromTrash")
        expectBanner("Restored")
        XCTAssertTrue(trashed.waitForNonExistence(timeout: 10))
    }
}
