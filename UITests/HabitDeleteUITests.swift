import XCTest

/// Deleting from the "…" menu of a page reached from the Habits tab (.472): the confirmation names the kind of note, the
/// note leaves the Habits tab and its notifications go.
final class HabitDeleteUITests: XCTestCase {
    private var app: XCUIApplication!
    private let habit = "Витамины 💊"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ link: String) {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPProvisionalNotifications",
                               "-SPOpen", link]
        app.launch()
    }

    /// The DEBUG list of pending notifications: whether one of them is the habit's. The screen reads the list once as it
    /// opens, and right after a fresh install the app may still be scheduling then, so the list is read again on the next
    /// launches until it has notifications (the other habits and tasks keep theirs) and says `expected` about the habit.
    private func habitHasPendingNotifications(expected: Bool, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        var found = !expected
        var scheduled = false
        for _ in 0..<4 {
            launch("superpooper://debug-notifications")
            let pending = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] 'Pending ('")).firstMatch
            XCTAssertTrue(pending.waitForExistence(timeout: 15), file: file, line: line)
            scheduled = pending.label.lowercased() != "pending (0)"
            let entry = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", habit)).firstMatch
            // The list shows only the rows on screen.
            for _ in 0..<8 where !entry.exists { app.swipeUp() }
            found = entry.exists
            app.terminate()
            if scheduled, found == expected { break }
            sleep(2)
        }
        XCTAssertTrue(scheduled, "the other habits and tasks keep theirs", file: file, line: line)
        return found
    }

    /// The owner's path: a repeatable task in the Habits tab, its page, "…", Delete.
    func testDeletingARepeatableTaskFromItsPageInHabitsRemovesItAndItsNotifications() {
        XCTAssertTrue(habitHasPendingNotifications(expected: true), "it has its reminder at first")

        launch("superpooper://habits")
        let row = app.buttons["habit:\(habit)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.dismissBanners()
        // Make it a repeatable task first: it moves to the Repeatable tasks group.
        openPage(of: row)
        let kind = app.segmentedControls["habitPage.kind"].buttons["Repeatable task"]
        app.scrollIntoView(kind)
        kind.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Repeatable tasks"].waitForExistence(timeout: 5))

        openPage(of: row)
        // Toolbar menus refuse the accessibility "scroll to visible" step, so tap by coordinate.
        app.buttons["taskPage.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let delete = app.buttons["action.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        // With a trash a delete happens at once; the banner offers Undo instead of a confirmation (.27143).
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'to trash'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["banner.undo"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists, "no confirmation")
        XCTAssertTrue(app.textFields["taskPage.name"].waitForNonExistence(timeout: 5), "the page closes")
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "it leaves the Habits tab")
        app.terminate()

        XCTAssertFalse(habitHasPendingNotifications(expected: false), "its notifications are gone")
    }

    private func openPage(of row: XCUIElement) {
        app.scrollIntoView(row)
        row.tap()
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 5))
        app.dismissBanners()
    }
}
