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
    }

    private func moreMenu(_ action: String) {
        // Toolbar menus refuse the accessibility "scroll to visible" step, so tap by coordinate.
        app.buttons["taskPage.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let item = app.buttons[action]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
    }

    func testRenameChangesTheName() {
        open("Записать идеи")
        let field = app.textFields["taskPage.name"]
        field.tap()
        field.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText(XCUIKeyboardKey.delete.rawValue)
        field.typeText("Записать идеи 2\n")
        let renamed = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Renamed'")).firstMatch
        XCTAssertTrue(renamed.waitForExistence(timeout: 5))
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
