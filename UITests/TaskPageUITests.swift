import XCTest

/// Task page operations on the rendered test vault. File effects are checked afterwards by
/// `scripts/check-vault-after-ui-tests.sh`.
final class TaskPageUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func open(_ task: String) {
        let encoded = task.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? task
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPSeedDemo",
                               "-SPOpen", "superpooper://task/\(encoded)"]
        app.launch()
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 10))
        // A banner of the launch sync (the first one moves notes to Soon) covers the name and the "…" button.
        app.dismissBanners()
    }

    private func moreMenu(_ action: String) {
        // Toolbar menus refuse the accessibility "scroll to visible" step, so tap by coordinate.
        app.buttons["taskPage.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let item = app.buttons[action]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
    }

    /// A habit's color is picked with the control of every color in Settings (.24481): a hex field before the system circle.
    func testAHabitColorHasTheHexFieldOfEveryColorControl() {
        open("Утро — завтрак 🥣")
        let hex = app.textFields["habitPage.color.hex"]
        app.scrollIntoView(hex)
        XCTAssertTrue(app.descendants(matching: .any)["habitPage.color.picker"].exists, "the system circle stands beside it")
        hex.tap()
        hex.typeText("34c759\n")
        XCTAssertTrue(app.buttons["habitPage.color.reset"].waitForExistence(timeout: 5), "an own color can be reset")
        XCTAssertEqual(hex.value as? String, "#34C759")
    }

    /// The "…" menu is the system menu, like every long-press menu of the app (.25075), not a popover of the app's own.
    func testTheMoreMenuIsTheSystemMenu() {
        open("Распечатать вопросы")
        app.buttons["taskPage.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["action.delete"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.popovers.firstMatch.exists, "no popover")
        XCTAssertFalse(app.buttons["PopoverDismissRegion"].exists, "no popover")
    }

    func testRenameChangesTheName() {
        open("Записать идеи")
        let field = app.textFields["taskPage.name"]
        field.tap()
        field.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText(XCUIKeyboardKey.delete.rawValue)
        field.typeText("Записать идеи 2\n")
        let renamed = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'banner' AND label CONTAINS 'Renamed'")).firstMatch
        XCTAssertTrue(renamed.waitForExistence(timeout: 10))
    }

    func testArchiveFromMoreMenu() {
        open("Купить батарейки 🔋")
        moreMenu("Archive")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Archived'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testDeleteAsksAndMovesToTrash() {
        open("Посмотреть сериал 🍿")
        moreMenu("Delete")
        let alert = app.alerts["Delete task?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'to trash'")).firstMatch.waitForExistence(timeout: 5))
    }

    /// A parent's subtasks go with it (.1965): the confirmation says how many.
    func testDeletingAParentSaysItsSubtasksGoAlong() {
        open("Повесить зеркало")
        let field = app.textFields["taskPage.subtask"].firstMatch
        for name in ["Купить дюбели", "Найти уровень"] {
            app.scrollIntoView(field)
            field.tap()
            field.typeText(name + "\n")
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "subtask:\(name)").firstMatch.waitForExistence(timeout: 5))
        }
        app.dismissBanners()
        moreMenu("action.delete")
        let alert = app.alerts["Delete task?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS '2 subtasks go with it.'")).firstMatch.exists)
        alert.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'to trash'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testLinkPreviousTaskThroughPicker() {
        open("Помыть окна")
        app.buttons["link.add.previous"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("отвёрт")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Найти отвёртку'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Найти отвёртку'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testLinkEventThroughSearchablePicker() {
        open("Сходить к стоматологу")
        app.swipeUp()
        app.buttons["event.pick.previous"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Call")
        let event = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Call with dad'")).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: 5))
        event.tap()
        XCTAssertTrue(app.staticTexts["Call with dad"].waitForExistence(timeout: 5))
    }
}
