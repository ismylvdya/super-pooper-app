import XCTest

/// Select mode in the pool (`scripts/sim.sh load-vault` first): started from a row's long-press menu, the bar's buttons
/// give way to Cancel and the actions on the picked tasks. Worm and Cancel write nothing; Delete is taken back with Undo,
/// so the notes stay as the vault has them for the other classes.
final class SelectUITests: XCTestCase {
    private var app: XCUIApplication!
    private let first = "Позвонить в банк"
    private let second = "Найти отвёртку"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPResetState", "-SPSeedDemo",
                               "-SPOpen", "superpooper://today"]
    }

    private func row(_ name: String) -> XCUIElement { app.buttons["title:\(name)"] }

    /// Long press on the first task → Select, then a tap picks the second.
    private func selectBoth() {
        app.launch()
        XCTAssertTrue(app.buttons["today.lists"].waitForExistence(timeout: 10))
        app.dismissBanners()
        let first = row(first)
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        app.scrollIntoView(first)
        first.press(forDuration: 1.2)
        let select = app.buttons["action.select"]
        XCTAssertTrue(select.waitForExistence(timeout: 5))
        select.tap()
        XCTAssertTrue(app.staticTexts["select.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["select.title"].label, "1 selected")
        let second = row(second)
        app.scrollIntoView(second)
        // In Select mode the row's own controls take no taps: the row does.
        second.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(app.staticTexts["select.title"].label, "2 selected")
    }

    func testSelectThenWormMakesOnePlate() {
        selectBoth()
        // The system menu's button wraps its own: XCUITest finds it, but not hittable by the identifier.
        app.buttons["select.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let worm = app.buttons["action.worm"]
        XCTAssertTrue(worm.waitForExistence(timeout: 5))
        worm.tap()
        XCTAssertTrue(app.buttons["today.lists"].waitForExistence(timeout: 5), "the action ends Select")
        let plate = app.otherElements["pool.worm"]
        XCTAssertTrue(plate.waitForExistence(timeout: 5))
        XCTAssertTrue(plate.buttons["title:\(first)"].exists)
        XCTAssertTrue(plate.buttons["title:\(second)"].exists)
    }

    func testSelectDeleteOffersUndo() {
        selectBoth()
        app.buttons["select.more"].tap()
        app.buttons["action.delete"].tap()
        XCTAssertTrue(row(first).waitForNonExistence(timeout: 5))
        XCTAssertFalse(row(second).exists)
        let undo = app.buttons["banner.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(row(first).waitForExistence(timeout: 5))
        XCTAssertTrue(row(second).waitForExistence(timeout: 5))
    }

    func testCancelLeavesSelect() {
        selectBoth()
        XCTAssertFalse(app.buttons["today.lists"].exists, "Select's buttons stand in place of Today's own")
        XCTAssertFalse(app.buttons["today.day"].exists)
        app.buttons["select.cancel"].tap()
        XCTAssertTrue(app.buttons["today.lists"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["today.day"].exists, "the day's name is back")
        XCTAssertFalse(app.staticTexts["select.title"].exists)
    }
}
