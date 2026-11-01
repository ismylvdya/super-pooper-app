import XCTest

/// Native swipes in the lists (.1237, .1471): to the right Done (Return in the Done list), to the left Delete after the
/// confirmation, or — in the archive and the trash — back. The files are checked by `scripts/check-vault-after-ui-tests.sh`.
final class SwipeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ link: String) {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPOpen", link]
        app.launch()
    }

    /// The list row that shows `text`.
    private func row(_ text: String) -> XCUIElement {
        app.cells.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
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

    /// A list of the Lists tab: a swipe to the left asks, then the task goes to the trash.
    func testListSwipeLeftDeletesAfterTheConfirmation() {
        launch("superpooper://lists/waiting")
        let task = row("Ждать ответа от арендодателя")
        XCTAssertTrue(task.waitForExistence(timeout: 10))
        app.dismissBanners()
        swipe(task, right: false, press: "delete")
        let alert = app.alerts["Delete task?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "the existing confirmation")
        alert.buttons["Delete"].tap()
        expectBanner("to trash")
        XCTAssertTrue(task.waitForNonExistence(timeout: 5))
    }

    /// A list of the Lists tab: a swipe to the right is Done (the task goes to the done folder).
    func testListSwipeRightIsDone() {
        launch("superpooper://lists/thisWeek")
        let task = row("Разобрать почту")
        XCTAssertTrue(task.waitForExistence(timeout: 10))
        app.dismissBanners()
        swipe(task, right: true, press: "done")
        XCTAssertTrue(task.waitForNonExistence(timeout: 10), "a done task leaves the Soon list")
    }

    /// The Done list: a filed task returns to Soon from its menu (Return) and with a swipe to the right.
    func testDoneListReturnsFiledTasks() {
        launch("superpooper://lists/done")
        let old = row("Старая сделанная задача")
        XCTAssertTrue(old.waitForExistence(timeout: 10))
        app.dismissBanners()
        app.scrollIntoView(old)
        old.press(forDuration: 1.2)
        let menuReturn = app.buttons["Return"]
        XCTAssertTrue(menuReturn.waitForExistence(timeout: 5), "the menu offers Return")
        menuReturn.tap()
        expectBanner("Старая сделанная задача")
        XCTAssertTrue(old.waitForNonExistence(timeout: 10))

        let milk = row("Купить молоко")
        XCTAssertTrue(milk.waitForExistence(timeout: 10))
        app.dismissBanners()
        swipe(milk, right: true, press: "returnFromDone")
        expectBanner("Купить молоко")
        XCTAssertTrue(milk.waitForNonExistence(timeout: 10))
    }

    /// Soon: to the left Not today (the full swipe) and Delete, to the right Done.
    func testSoonOffersNotTodayDeleteAndDone() {
        launch("superpooper://review")
        let task = row("Сдать отчёт")
        XCTAssertTrue(task.waitForExistence(timeout: 10))
        app.dismissBanners()
        reveal(task, right: false)
        XCTAssertTrue(app.buttons["swipe.notToday"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["swipe.delete"].exists)
        XCTAssertLessThan(app.buttons["swipe.delete"].frame.minX, app.buttons["swipe.notToday"].frame.minX,
                          "Not today stands at the edge, Delete after it")
        // A drag back closes the buttons; the next one shows the other side.
        reveal(task, right: true)
        XCTAssertTrue(app.buttons["swipe.notToday"].waitForNonExistence(timeout: 3))
        reveal(task, right: true)
        XCTAssertTrue(app.buttons["swipe.done"].waitForExistence(timeout: 3))
    }

    /// The archive: a swipe to the left brings an archived task back to Soon.
    func testArchiveSwipeLeftRestoresToSoon() {
        launch("superpooper://archive")
        let task = row("Архивная задача")
        XCTAssertTrue(task.waitForExistence(timeout: 10))
        app.dismissBanners()
        swipe(task, right: false, press: "restoreThisWeek")
        XCTAssertTrue(task.waitForNonExistence(timeout: 10), "it leaves the archive")
    }

    /// The trash: a note deleted with a swipe comes back with a swipe to the left.
    func testTrashSwipeLeftRestores() {
        launch("superpooper://lists/thisWeek")
        let task = row("Связь на несуществующую")
        XCTAssertTrue(task.waitForExistence(timeout: 10))
        app.dismissBanners()
        swipe(task, right: false, press: "delete")
        let alert = app.alerts["Delete task?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete"].tap()
        expectBanner("to trash")
        app.terminate()

        launch("superpooper://trash")
        let trashed = row("Связь на несуществующую")
        XCTAssertTrue(trashed.waitForExistence(timeout: 10))
        app.dismissBanners()
        swipe(trashed, right: false, press: "restoreFromTrash")
        expectBanner("Restored")
        XCTAssertTrue(trashed.waitForNonExistence(timeout: 10))
    }
}
