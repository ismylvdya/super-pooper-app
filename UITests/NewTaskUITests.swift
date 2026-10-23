import XCTest

/// "+" in the morning review creates a task and "+" in Habits creates a habit: an empty page whose note
/// is written when the page is left with Back.
final class NewTaskUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ link: String) {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPOpen", link]
        app.launch()
    }

    private func expectCreatedBanner(_ name: String) {
        let banner = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Created' AND label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
    }

    func testReviewRowOpensTheTaskAndPlusCreatesOne() {
        launch("superpooper://review")
        let row = app.staticTexts["Сдать отчёт"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let plus = app.navigationBars["Morning review"].buttons["task.new"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        plus.tap()
        let name = app.textFields["taskPage.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Позвонить врачу")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        expectCreatedBanner("Позвонить врачу")
    }

    func testPlusInHabitsCreatesAHabit() {
        launch("superpooper://habits")
        let plus = app.buttons["habits.new"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        plus.tap()
        let name = app.textFields["taskPage.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Читать 20 минут")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        expectCreatedBanner("Читать 20 минут")
        XCTAssertTrue(app.descendants(matching: .any)["habitDay:Читать 20 минут"].waitForExistence(timeout: 5))
    }

    func testTapInHabitsMarksToday() {
        launch("superpooper://habits")
        let day = app.descendants(matching: .any)["habitDay:Медитация 🧘"]
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        day.press(forDuration: 1.2)
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Unmark"].waitForExistence(timeout: 5), "a marked day offers Unmark")
        // Close the menu without unmarking: the day stays done for scripts/check-vault-after-ui-tests.sh.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
    }
}
