import XCTest

/// The plate at the top of Settings counts down to the end of the app's signature (`-SPSignatureHoursLeft` stands in
/// for the provisioning profile, which the simulator has none of).
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
}
