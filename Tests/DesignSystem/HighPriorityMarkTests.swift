import SwiftUI
import Testing
@testable import SuperPooperApp

/// A high-priority task's plate is soft red wherever a task stands; there is no icon before its name and no setting
/// to choose another look (D-184). The priority icon (in the review's chip) is the triangle (.25540).
struct HighPriorityMarkTests {
    private let high = makeTask("Call the bank") { $0.isHighPriority = true }
    private let plain = makeTask("Read")

    @Test func aHighPriorityTaskIsFilledInTheHighColor() {
        #expect(TestConfig.tokens.plateTint(for: high) != nil)
        #expect(TestConfig.tokens.opacity(.highPriorityFill) > 0 && TestConfig.tokens.opacity(.highPriorityFill) < 1, "soft, not solid")
    }

    @Test func aPlainTaskKeepsItsPlate() {
        #expect(TestConfig.tokens.plateTint(for: plain) == nil)
    }

    @Test func thePriorityIconIsTheTriangle() {
        #expect(TestConfig.decode(IconSet.self, "icons.json")[.high] == "exclamationmark.triangle.fill")
    }
}
