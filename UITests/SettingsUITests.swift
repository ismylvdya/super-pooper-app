import XCTest

/// The plate at the top of Settings counts down to the end of the app's signature (`-SPSignatureHoursLeft` stands in
/// for the provisioning profile, which the simulator has none of). The Lists icon is picked by name.
final class SettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func openSettings(signatureHoursLeft hours: Int) {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPSignatureHoursLeft", "\(hours)",
                               "-SPOpen", "superpooper://settings"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["settings.link.taskSettings"].waitForExistence(timeout: 10))
    }

    private var plate: XCUIElement { app.descendants(matching: .any)["settings.signing"] }

    func testTheSignaturePlateSaysTheDaysLeft() {
        openSettings(signatureHoursLeft: 30)
        XCTAssertTrue(plate.waitForExistence(timeout: 5))
        XCTAssertTrue(plate.label.contains("1 day left"), plate.label)
    }

    func testOnTheLastDayThePlateCountsHours() {
        openSettings(signatureHoursLeft: 5)
        XCTAssertTrue(plate.waitForExistence(timeout: 5))
        XCTAssertTrue(plate.label.contains("5 hours left"), plate.label)
    }

    func testASignatureMoreThanAWeekAwayHasNoPlate() {
        openSettings(signatureHoursLeft: 8 * 24)
        XCTAssertFalse(plate.waitForExistence(timeout: 3))
    }

    /// The search in Settings (.searchable) finds a row by its title and opens the page it is on.
    func testSearchFindsASettingAndOpensItsPage() {
        openSettings(signatureHoursLeft: 8 * 24)
        app.swipeDown()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("bell")
        let result = app.descendants(matching: .any).matching(identifier: "settings.search.result").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["settings.link.habitSettings"].exists, "only the results show")
        result.tap()
        XCTAssertTrue(app.buttons["settings.listsIcon"].waitForExistence(timeout: 10), "the tasks' settings page")
    }

    /// A plain menu of names; the pick stays once the menu closes. The test puts the gun back, so the other tests see
    /// the default.
    func testTheListsIconIsPickedByName() {
        openSettings(signatureHoursLeft: 8 * 24)
        app.descendants(matching: .any)["settings.link.taskSettings"].tap()
        let picker = app.buttons["settings.listsIcon"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        app.scrollIntoView(picker)
        XCTAssertTrue(shown(by: picker).contains("Gun"), shown(by: picker))
        pick("Double guns fill back", in: picker)
        XCTAssertTrue(shown(by: picker).contains("Double guns fill back"), shown(by: picker))
        pick("Gun", in: picker)
        XCTAssertFalse(shown(by: picker).contains("Double"), shown(by: picker))
    }

    /// High priority (.25226): by default the triangle stands before the task's name in the pool; with "Red plate" in
    /// the settings the icon is gone (the plate is red instead). The test puts the default back for the other tests.
    func testHighPriorityIsShownTheWayTheSettingsSay() {
        openSettings(signatureHoursLeft: 8 * 24)
        app.descendants(matching: .any)["settings.link.taskSettings"].tap()
        let picker = app.segmentedControls["settings.pool.highPriority"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        app.scrollIntoView(picker)
        XCTAssertTrue(picker.buttons["Icon before the name"].isSelected)
        let icon = app.descendants(matching: .any)["highPriority:Позвонить в банк"]
        app.tabBars.buttons["Today"].tap()
        app.dismissBanners()
        app.scrollIntoView(icon)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Red plate"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["title:Позвонить в банк"].waitForExistence(timeout: 5))
        XCTAssertTrue(icon.waitForNonExistence(timeout: 5), "with the red plate there is no icon before the name")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Icon before the name"].tap()
        XCTAssertTrue(picker.buttons["Icon before the name"].isSelected)
    }

    private func shown(by picker: XCUIElement) -> String { "\(picker.label) \(picker.value as? String ?? "")" }

    private func pick(_ name: String, in picker: XCUIElement) {
        picker.tap()
        let option = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", name, picker.identifier)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "\(name) is in the menu")
        option.tap()
        XCTAssertTrue(option.waitForNonExistence(timeout: 5), "the menu closes")
    }
}
