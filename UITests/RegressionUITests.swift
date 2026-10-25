import XCTest

/// Bugs that only show in the interface, each checked the way a user would meet it.
final class RegressionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ link: String) {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPResetState", "-SPOpen", link]
        app.launch()
    }

    /// The morning review is a sheet with its own pages: a subtask tapped there opens there, not under the sheet.
    func testASubtaskOpensInsideTheMorningReview() {
        launch("superpooper://review")
        if !app.navigationBars["Morning review"].waitForExistence(timeout: 6) { app.buttons["today.review"].tap() }
        let row = app.staticTexts["Позвонить в банк"]
        for _ in 0..<4 where !row.waitForExistence(timeout: 2) { app.swipeUp() }
        row.tap()
        let field = app.textFields["taskPage.subtask"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Взять паспорт\n")
        let subtask = app.buttons.containing(.staticText, identifier: "Взять паспорт").firstMatch
        XCTAssertTrue(subtask.waitForExistence(timeout: 5))
        subtask.tap()
        let opened = app.textFields.matching(identifier: "taskPage.name")
            .matching(NSPredicate(format: "value == %@", "Взять паспорт")).firstMatch
        XCTAssertTrue(opened.waitForExistence(timeout: 5))
        // In the sheet the parent page went one step back; under the sheet it would still be on top.
        let parent = app.textFields.matching(identifier: "taskPage.name")
            .matching(NSPredicate(format: "value == %@", "Позвонить в банк")).firstMatch
        XCTAssertTrue(parent.waitForNonExistence(timeout: 3), "the subtask's page is shown in the sheet, not under it")
    }
}
