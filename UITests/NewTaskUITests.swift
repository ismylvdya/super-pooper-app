import XCTest

/// "+" on Today and in the morning review creates a this-week note and opens its page.
final class NewTaskUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPOpen", "superpooper://today"]
    }

    func testPlusOnTodayCreatesANamedTask() {
        app.launch()
        let plus = app.buttons["task.new"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        plus.tap()
        let name = app.textFields["taskPage.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Купить хлеб\n")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Renamed'")).firstMatch.waitForExistence(timeout: 15))
    }

    func testReviewRowOpensTheTaskAndPlusCreatesOne() {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPOpen", "superpooper://review"]
        app.launch()
        let row = app.staticTexts["Сдать отчёт"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 5))
        app.buttons["Morning review"].firstMatch.tap()
        let plus = app.navigationBars["Morning review"].buttons["task.new"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        plus.tap()
        let name = app.textFields["taskPage.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Позвонить врачу\n")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Renamed'")).firstMatch.waitForExistence(timeout: 15))
    }
}
