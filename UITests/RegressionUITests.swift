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

    /// Habits (.22478): once a row's long-press menu has closed, the row looks as it did before the press right away, with
    /// no pressed look left on its plate; a tap still opens the habit's page.
    func testAHabitRowLeavesNoHighlightOnceItsMenuCloses() throws {
        launch("superpooper://habits")
        let name = "Медитация 🧘"
        let row = app.cells.containing(.button, identifier: "habit:\(name)").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.dismissBanners()
        let rest = try pixels(of: row)
        app.buttons["habit:\(name)"].press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Partially"].waitForExistence(timeout: 5), "the menu is open")
        // Away from the menu: the bar at the top.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        XCTAssertTrue(app.buttons["Partially"].waitForNonExistence(timeout: 3))
        usleep(400_000)
        let after = try pixels(of: row)
        XCTAssertEqual(rest.count, after.count)
        let differing = zip(rest, after).filter { abs(Int($0) - Int($1)) > 6 }.count
        XCTAssertLessThan(differing, rest.count / 200, "the row is back to its rest look")

        app.buttons["habit:\(name)"].tap()
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 5), "a tap opens the page")
    }

    /// The RGB channels of an element's picture.
    private func pixels(of element: XCUIElement) throws -> [UInt8] {
        let image = try XCTUnwrap(element.screenshot().image.cgImage)
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(data: &data, width: image.width, height: image.height, bitsPerComponent: 8,
                                              bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return data.enumerated().filter { $0.offset % 4 != 3 }.map(\.element)
    }

    /// The morning review is a sheet with its own pages: a subtask tapped there opens there, not under the sheet.
    func testASubtaskOpensInsideTheMorningReview() {
        launch("superpooper://review")
        if !app.navigationBars["Morning review"].waitForExistence(timeout: 6) { app.buttons["today.review"].tap() }
        // A banner over the row would take the tap.
        app.dismissBanners()
        let row = app.staticTexts["Позвонить в банк"]
        app.scrollIntoView(row)
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
        // Slowly, and held over the target: a quick drop can land before the target notices the drag.
        first.press(forDuration: 1.2, thenDragTo: second, withVelocity: .slow, thenHoldForDuration: 0.5)
        let moved = NSPredicate { _, _ in first.frame.minY < second.frame.minY }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5), .completed,
                       "the dragged subtask is above the one it was dropped on")
    }

    /// A row that opens a page opens it from anywhere on it, not only from its title or chevron (the tap lands in the
    /// row's middle, on the empty space between them).
    func testARowOpensItsPageFromItsEmptyMiddle() {
        launch("superpooper://settings")
        let settingsRow = app.buttons["settings.link.taskSettings"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 10))
        settingsRow.tap()
        XCTAssertTrue(settingsRow.waitForNonExistence(timeout: 6), "Settings → Today opened")
        launch("superpooper://lists")
        let listRow = app.buttons["lists.pleasant"]
        XCTAssertTrue(listRow.waitForExistence(timeout: 10))
        listRow.tap()
        XCTAssertTrue(listRow.waitForNonExistence(timeout: 6), "Lists → Pleasant opened")
    }

    /// Every text field of the settings keeps a typed trailing space visible (right-aligned text drops it): the field
    /// is as wide as its text, so the space after the word widens it, and the space is kept as typed.
    func testSettingsFieldsShowATypedTrailingSpace() {
        launch("superpooper://settings")
        let link = app.buttons["settings.link.taskSettings"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
        let vault = app.textFields.matching(NSPredicate(format: "placeholderValue == 'Automatic'")).firstMatch
        XCTAssertTrue(vault.waitForExistence(timeout: 5))
        vault.tap()
        vault.typeText("My")
        let word = vault.frame.width
        vault.typeText(" ")
        XCTAssertEqual(vault.value as? String, "My ")
        XCTAssertGreaterThan(vault.frame.width, word, "the space after the word is shown")
        vault.typeText("Vault")
        XCTAssertEqual(vault.value as? String, "My Vault")
        vault.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
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
