import XCTest

/// The pool's sections (`scripts/sim.sh load-vault` first): a task dragged under another section's header stays there
/// that day, also after a relaunch; a section dragged by its header goes after the whole section it was dropped below.
final class PoolSectionsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-SPVaultPath", "TestVault", "-SPSkipOnboarding", "-SPNow", "11:30", "-SPResetState", "-SPSeedDemo",
                               "-SPOpen", "superpooper://today"]
    }

    private func launch() {
        app.launch()
        XCTAssertTrue(app.buttons["today.lists"].waitForExistence(timeout: 10))
        app.dismissBanners()
    }

    private func header(_ id: String) -> XCUIElement { app.descendants(matching: .any)["pool.section.\(id)"].firstMatch }

    private func expect(_ element: XCUIElement, toBe condition: @escaping (XCUIElement) -> Bool, _ message: String) {
        let met = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in element.exists && condition(element) }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [met], timeout: 5), .completed, message)
    }

    /// Morning dragged by its header below Day's header goes after the whole Day section: Day is the pool's first section.
    func testASectionDraggedBelowAnotherHeaderGoesAfterThatSection() {
        launch()
        let morning = header("morning")
        let day = header("day")
        XCTAssertTrue(morning.waitForExistence(timeout: 10) && day.waitForExistence(timeout: 5))
        XCTAssertLessThan(morning.frame.midY, day.frame.midY)
        let firstOfDay = app.buttons["title:Неизвестное правило"]
        morning.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 1.2, thenDragTo: day.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 1.2)), withVelocity: .slow,
                   thenHoldForDuration: 0.5)
        expect(day, toBe: { day in
            let water = self.app.buttons["title:Выпить воды 💧"]
            return firstOfDay.exists && day.frame.midY < firstOfDay.frame.midY && (!water.exists || water.frame.midY > firstOfDay.frame.midY)
        }, "Day comes first, Morning's habits after it")
    }
}
