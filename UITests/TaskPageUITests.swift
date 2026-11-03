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

    /// The app again from the start, on the page of `task` (whatever that page shows now).
    private func relaunch(opening task: String) {
        app.terminate()
        let encoded = task.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? task
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPSeedDemo",
                               "-SPOpen", "superpooper://task/\(encoded)"]
        app.launch()
        XCTAssertTrue(app.buttons["taskPage.more"].waitForExistence(timeout: 10))
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

    /// With a trash, Delete asks nothing: the note goes to the trash and the banner offers Undo (.27143).
    func testDeleteMovesToTrashAtOnceWithUndo() {
        open("Посмотреть сериал 🍿")
        moreMenu("Delete")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'to trash'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["banner.undo"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists, "no confirmation")
        XCTAssertTrue(app.textFields["taskPage.name"].waitForNonExistence(timeout: 5), "the page closes")
    }

    /// Undo in the banner brings a deleted note back; the page of a note in the trash says so, and its "…" menu brings
    /// it back from there (.28117).
    func testUndoAndRestoreFromTrashBringADeletedNoteBack() {
        let name = "Забрать посылку на почте"
        open(name)
        moreMenu("action.delete")
        let undo = app.buttons["banner.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        relaunch(opening: name)
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 10), "Undo brought it back")

        moreMenu("action.delete")
        XCTAssertTrue(app.textFields["taskPage.name"].waitForNonExistence(timeout: 5))
        relaunch(opening: name)
        XCTAssertTrue(app.staticTexts["In the trash"].waitForExistence(timeout: 10))
        moreMenu("action.restoreFromTrash")
        XCTAssertTrue(app.textFields["taskPage.name"].waitForExistence(timeout: 10), "back from the trash")
    }

    /// The "…" menu of an archived note offers Restore from archive instead of Archive (.28117).
    func testAnArchivedNoteIsRestoredFromItsMenu() {
        open("Собрать шкаф")
        moreMenu("action.archive")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Archived'")).firstMatch.waitForExistence(timeout: 5))
        app.dismissBanners()
        app.buttons["taskPage.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let restore = app.buttons["action.restoreFromArchive"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["action.archive"].exists, "an archived note is not archived again")
        restore.tap()
        app.dismissBanners()
        app.buttons["taskPage.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["action.archive"].waitForExistence(timeout: 5), "out of the archive again")
        XCTAssertFalse(app.buttons["action.restoreFromArchive"].exists)
    }

    /// A parent's subtasks go with it (.1965): the banner names them.
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
        let banner = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'banner' AND label CONTAINS 'to trash' AND label CONTAINS 'Купить дюбели' AND label CONTAINS 'Найти уровень'"))
            .firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
    }

}
