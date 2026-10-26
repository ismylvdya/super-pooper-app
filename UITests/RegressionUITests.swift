import XCTest

/// Bugs that only show in the interface, each checked the way a user would meet it.
final class RegressionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ link: String, textSize: String? = nil) {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPResetState", "-SPOpen", link]
        if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
        app.launch()
    }

    /// The morning review is a sheet with its own pages: a subtask tapped there opens there, not under the sheet.
    func testASubtaskOpensInsideTheMorningReview() {
        launch("superpooper://review")
        if !app.navigationBars["This week"].waitForExistence(timeout: 6) { app.buttons["today.review"].tap() }
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

    /// A subtask's name shows as typed: underscores around a word are part of the name, not Markdown italics.
    func testASubtaskNameShowsAsTyped() {
        launch("superpooper://task/Позвонить в банк")
        let field = app.textFields["taskPage.subtask"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("Взять _синюю_ ручку\n")
        XCTAssertTrue(app.staticTexts["Взять _синюю_ ручку"].waitForExistence(timeout: 5))
    }

    /// A subtask dragged onto another one on the parent's page takes its place (by name "Шаг два" comes first).
    func testASubtaskDraggedOntoAnotherTakesItsPlace() {
        launch("superpooper://task/Позвонить в банк")
        let field = app.textFields["taskPage.subtask"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("Шаг один\n")
        field.tap()
        field.typeText("Шаг два\n")
        let first = app.descendants(matching: .any).matching(identifier: "subtask:Шаг один").firstMatch
        let second = app.descendants(matching: .any).matching(identifier: "subtask:Шаг два").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5) && second.waitForExistence(timeout: 5))
        XCTAssertLessThan(second.frame.minY, first.frame.minY)
        first.press(forDuration: 1.2, thenDragTo: second)
        let moved = NSPredicate { _, _ in first.frame.minY < second.frame.minY }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5), .completed,
                       "the dragged subtask is above the one it was dropped on")
    }

    /// With big text the High / Today / Tomorrow chips move to a second line instead of cutting their titles.
    func testQuickChipsWrapInsteadOfCuttingTheirTitles() {
        launch("superpooper://task/Позвонить в банк", textSize: "UICTContentSizeCategoryAccessibilityL")
        let high = app.buttons["taskPage.chip.high"]
        let tomorrow = app.buttons["taskPage.chip.tomorrow"]
        XCTAssertTrue(tomorrow.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(tomorrow.frame.minY, high.frame.maxY, "the last chip goes under the first one")
    }

    /// With the biggest text an onboarding step that does not fit scrolls, so its explanation is not cut.
    func testOnboardingStepsScrollWithTheBiggestText() {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPResetState",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let message = app.scrollViews.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Choose the TaskNotes folder'")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 8), "the explanation is in a scroll view")
    }
}
