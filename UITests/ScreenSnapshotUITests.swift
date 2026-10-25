import XCTest

/// Reference pictures of the main screens on the rendered test vault. `scripts/snapshots.sh` runs them on
/// each device, theme and text size and compares them with a saved set, so a refactoring that should not
/// change anything on screen can be checked. With `SP_SNAPSHOT_DIR` set the pictures go to that folder,
/// otherwise they are attached to the test result. `SP_SNAPSHOT_TODAY` (YYYY-MM-DD) fixes the date, so habits
/// of the weekday and due dates are the same whatever day the pictures are taken; the vault must be rendered
/// for the same date (`scripts/sim.sh load-vault <date>`).
final class ScreenSnapshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Today

    func testTodayPages() {
        launch("superpooper://today")
        snap("today-pool")
        app.swipeLeft()
        settle()
        snap("today-timeline")
    }

    func testTodayStacked() {
        launch("superpooper://today", arrangement: "stacked")
        snap("today-stacked")
    }

    func testTodaySideBySide() {
        launch("superpooper://today", arrangement: "sideBySide")
        snap("today-side-by-side")
    }

    func testTodayLandscape() {
        launch("superpooper://today")
        XCUIDevice.shared.orientation = .landscapeLeft
        settle()
        snap("today-landscape")
    }

    func testPoolTaskMenu() {
        launch("superpooper://today")
        longPress(app.buttons["title:Оплатить интернет"])
        snap("menu-pool-task")
    }

    func testPoolHabitMenu() {
        launch("superpooper://today")
        longPress(app.buttons["title:Выпить воды 💧"])
        snap("menu-pool-habit")
    }

    // MARK: - Pages

    func testTaskPage() {
        launch("superpooper://task/Распечатать вопросы")
        snapTopAndBottom("task-page")
        app.buttons["taskPage.more"].tap()
        settle()
        snap("menu-task-page")
    }

    func testHabitPage() {
        launch("superpooper://habit/Медитация 🧘")
        snapTopAndBottom("habit-page")
    }

    func testNewTask() {
        launch("superpooper://today")
        app.buttons["today.newTask"].tap()
        settle()
        snap("new-task")
    }

    func testMorningReview() {
        launch("superpooper://review")
        snapTopAndBottom("review")
    }

    func testHabits() {
        launch("superpooper://habits")
        snap("habits")
        longPress(app.descendants(matching: .any)["habitDay:Медитация 🧘"])
        snap("menu-habits-row")
    }

    func testSettings() {
        launch("superpooper://settings")
        snapTopAndBottom("settings")
    }

    func testTodaySettings() {
        launch("superpooper://settings")
        app.buttons["settings.link.taskSettings"].tap()
        settle()
        snapTopAndBottom("settings-today")
    }

    func testHabitSettings() {
        launch("superpooper://settings")
        app.buttons["settings.link.habitSettings"].tap()
        settle()
        snapTopAndBottom("settings-habits")
    }

    func testWidgets() {
        launch("superpooper://debug-widgets")
        snapTopAndBottom("widgets")
    }

    // MARK: - Helpers

    /// A fixed clock (and date), a fresh day state and the demo calendar; banners are swiped away.
    private func launch(_ link: String, arrangement: String = "paged") {
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPResetState", "-SPSeedDemo",
                               "-SPArrangement", arrangement, "-SPOpen", link]
        if let today = ProcessInfo.processInfo.environment["SP_SNAPSHOT_TODAY"] { app.launchArguments += ["-SPToday", today] }
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        settle(seconds: 2)
        waitForNoBanners()
    }

    /// Banners come and go with the sync; a picture is taken without them (swiped away or hidden by time).
    private func waitForNoBanners() {
        let banner = app.descendants(matching: .any).matching(identifier: "banner").firstMatch
        for _ in 0..<3 where banner.exists {
            banner.swipeUp()
            _ = banner.waitForNonExistence(timeout: 3)
        }
        XCTAssertTrue(banner.waitForNonExistence(timeout: 15), "banners hide by themselves")
        settle()
    }

    private func settle(seconds: TimeInterval = 1) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func longPress(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        element.press(forDuration: 1.2)
        settle()
    }

    private func snapTopAndBottom(_ name: String) {
        snap("\(name)-top")
        for _ in 0..<6 { app.swipeUp() }
        settle()
        snap("\(name)-bottom")
    }

    private func snap(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if let folder = ProcessInfo.processInfo.environment["SP_SNAPSHOT_DIR"] {
            let url = URL(fileURLWithPath: folder, isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            XCTAssertNoThrow(try png.write(to: url.appendingPathComponent("\(name).png")))
        } else {
            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
