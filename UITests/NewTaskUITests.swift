import XCTest

/// The "+" beside the tab bar creates a task, or a habit in Habits: an empty page whose note is written when the page
/// is left with Back, or at once on Return in its name (.1571).
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
        let banner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'banner' AND label BEGINSWITH 'Created' AND label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
    }

    /// A review row opens its task inside the sheet; the review has no "+" any more.
    func testReviewRowOpensTheTask() {
        launch("superpooper://review")
        XCTAssertTrue(app.navigationBars["Morning review"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Morning review"].buttons["task.new"].exists)
        // A banner over the row would take the tap.
        app.dismissBanners()
        // The list is long and lazy: scroll down to the row.
        let row = app.staticTexts["Позвонить в банк"]
        app.scrollIntoView(row)
        row.tap()
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 5))
    }

    /// The "+" beside the tab bar opens a new task on Tasks, its name ready for typing, and a new habit on Habits.
    func testPlusOnEveryTabOpensTheNewItemPage() {
        launch("superpooper://today")
        let plus = app.buttons["tabBar.newItem"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        app.dismissBanners()
        plus.tap()
        let name = app.textFields["taskPage.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the name is focused")
        XCTAssertEqual(name.placeholderValue, "New task")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.tabBars.buttons["Habits"].tap()
        plus.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.placeholderValue, "New habit")
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    /// The slider under the name turns the new task into a new habit without losing what was typed; Return then saves
    /// a habit (`scripts/check-vault-after-ui-tests.sh` checks its status).
    func testSwitchingToHabitKeepsTheTypedName() {
        launch("superpooper://today")
        let plus = app.buttons["tabBar.newItem"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        app.dismissBanners()
        plus.tap()
        let name = app.textFields["taskPage.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.typeText("Stretch")
        let kind = app.segmentedControls["newItem.kind"]
        XCTAssertTrue(kind.exists)
        XCTAssertFalse(app.segmentedControls["habitPage.kind"].exists, "a task has no habit options")
        kind.buttons["Habit"].tap()
        XCTAssertEqual(name.value as? String, "Stretch")
        XCTAssertTrue(app.segmentedControls["habitPage.kind"].waitForExistence(timeout: 5), "the habit's sections show")
        name.tap()
        app.typeText("\n")
        expectCreatedBanner("Stretch")
        XCTAssertTrue(app.buttons["taskPage.more"].waitForExistence(timeout: 5), "the page is the habit's own page now")
        XCTAssertTrue(app.segmentedControls["habitPage.kind"].exists)
    }

    func testPlusInHabitsCreatesAHabit() {
        launch("superpooper://habits")
        let plus = app.buttons["tabBar.newItem"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        app.dismissBanners()
        plus.tap()
        let name = app.textFields["taskPage.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Читать 20 минут")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        expectCreatedBanner("Читать 20 минут")
        XCTAssertTrue(app.descendants(matching: .any)["habitDay:Читать 20 минут"].waitForExistence(timeout: 5))
    }

    /// A new task opens with the cursor in its name. Return saves the note at once ("Created"), closes the keyboard and
    /// stays on the page, which is the task's own page from then on: an edit there is written to the note, and Back
    /// creates no second note (`scripts/check-vault-after-ui-tests.sh` checks the file).
    func testReturnInTheNameSavesTheTaskAndStaysOnItsPage() {
        launch("superpooper://today")
        let plus = app.buttons["tabBar.newItem"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        app.dismissBanners()
        plus.tap()
        let name = app.textFields["taskPage.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the keyboard is up without a tap")
        app.typeText("Купить хлеб\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Return closes the keyboard")
        expectCreatedBanner("Купить хлеб")
        XCTAssertTrue(app.buttons["taskPage.more"].waitForExistence(timeout: 5), "the page is the task's own page now")
        XCTAssertEqual(name.value as? String, "Купить хлеб")
        let high = app.switches["taskPage.high"]
        app.scrollIntoView(high)
        high.switches.firstMatch.tap()
        let switchedOn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: high)
        XCTAssertEqual(XCTWaiter().wait(for: [switchedOn], timeout: 5), .completed)
        // The first banner goes first, so a second one would show.
        app.dismissBanners()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["tabBar.newItem"].waitForExistence(timeout: 5))
        let second = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'banner' AND label BEGINSWITH 'Created'")).firstMatch
        XCTAssertFalse(second.waitForExistence(timeout: 3), "Back creates no second note")
    }

    /// Return with a name a note cannot take saves nothing: the title keeps pointing at the problem, the page stays a draft.
    func testReturnWithANameANoteCannotTakeSavesNothing() {
        launch("superpooper://today")
        let plus = app.buttons["tabBar.newItem"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        app.dismissBanners()
        plus.tap()
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 5))
        app.typeText("Встреча: Пётр\n")
        XCTAssertTrue(app.descendants(matching: .any)["taskPage.name.problem"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "banner").firstMatch.waitForExistence(timeout: 3),
                       "nothing is saved")
        XCTAssertFalse(app.buttons["taskPage.more"].exists, "still the new task page")
    }

    /// Another tab only hides the new task page: coming back finds it as it was left — after Return, the task's own
    /// page — and Back then creates no second note.
    func testAnotherTabKeepsTheNewTaskPage() {
        launch("superpooper://today")
        let plus = app.buttons["tabBar.newItem"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        app.dismissBanners()
        plus.tap()
        let name = app.textFields["taskPage.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        app.typeText("Полить цветы\n")
        expectCreatedBanner("Полить цветы")
        app.tabBars.buttons["Habits"].tap()
        XCTAssertTrue(app.buttons["tabBar.newItem"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Tasks"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Полить цветы")
        XCTAssertTrue(app.buttons["taskPage.more"].exists)
        app.dismissBanners()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let second = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'banner' AND label BEGINSWITH 'Created'")).firstMatch
        XCTAssertFalse(second.waitForExistence(timeout: 3), "Back creates no second note")
    }

    /// A name a note cannot take is pointed out in the title while it is typed.
    func testANameANoteCannotTakeIsShownInTheTitle() {
        launch("superpooper://today")
        let plus = app.buttons["tabBar.newItem"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        app.dismissBanners()
        plus.tap()
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 5))
        app.typeText("Встреча: Анна")
        XCTAssertTrue(app.descendants(matching: .any)["taskPage.name.problem"].waitForExistence(timeout: 5))
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        app.typeText(" Анна")
        XCTAssertTrue(app.descendants(matching: .any)["taskPage.name.problem"].waitForNonExistence(timeout: 5))
    }

    /// A list of a later planning level in the Lists tab brings its task to Soon ("Add to Soon").
    func testSomedayListAddsATaskToSoon() {
        launch("superpooper://lists/someday")
        let add = app.buttons["lists.toThisWeek.Выучить испанский"]
        for _ in 0..<4 where !add.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertEqual(add.label, "Add to Soon")
        add.tap()
        let banner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'banner' AND label CONTAINS 'Moved to Soon' AND label CONTAINS 'Выучить испанский'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 25))
        XCTAssertTrue(add.waitForNonExistence(timeout: 5), "a this-week task has no + any more")
    }

    func testTapInHabitsMarksToday() {
        launch("superpooper://habits")
        let day = app.descendants(matching: .any)["habitDay:Медитация 🧘"]
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        day.press(forDuration: 1.2)
        let done = app.buttons["DONE"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Unmark"].waitForExistence(timeout: 5), "a marked day offers Unmark")
        // Close the menu without unmarking: the day stays done for scripts/check-vault-after-ui-tests.sh.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
    }
}
