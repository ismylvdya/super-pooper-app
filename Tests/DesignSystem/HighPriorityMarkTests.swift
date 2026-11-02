import SwiftUI
import Testing
@testable import SuperPooperApp

/// A high-priority task stands out by the look chosen in the settings, in the pool and on the timeline alike: the
/// priority icon before its name, or its whole plate in a soft red (.25226, .25611); the icon is the triangle (.25540).
struct HighPriorityMarkTests {
    private let high = makeTask("Call the bank") { $0.isHighPriority = true }
    private let plain = makeTask("Read")

    @Test func theIconLooksLeadWithTheTriangle() {
        let mark = HighPriorityMark(look: .leadingIcon, task: high)
        #expect(mark.leadsWithIcon)
        #expect(!mark.fillsPlate)
        #expect(TestConfig.tokens.plateTint(mark) == nil)
        #expect(TestConfig.decode(IconSet.self, "icons.json")[.high] == "exclamationmark.triangle.fill")
    }

    @Test func theFillLookTintsThePlateInTheHighColor() {
        let mark = HighPriorityMark(look: .fill, task: high)
        #expect(mark.fillsPlate)
        #expect(!mark.leadsWithIcon)
        #expect(TestConfig.tokens.plateTint(mark) != nil)
        #expect(TestConfig.tokens.opacity(.highPriorityFill) > 0 && TestConfig.tokens.opacity(.highPriorityFill) < 1, "soft, not solid")
    }

    @Test func aPlainTaskAndAViewWithoutALookAreNotMarked() {
        for look in AppSettings.HighPriorityLook.allCases {
            let mark = HighPriorityMark(look: look, task: plain)
            #expect(!mark.leadsWithIcon && !mark.fillsPlate)
        }
        let widget = HighPriorityMark(look: nil, task: high)
        #expect(!widget.leadsWithIcon && !widget.fillsPlate)
    }

    /// The looks the settings offer and the default come from the config.
    @Test func theLooksAndTheDefaultComeFromTheConfig() {
        #expect(TestConfig.rules.pool.highPriorityLooks == [.leadingIcon, .fill])
        #expect(TestConfig.defaults.pool.highPriorityLook == .leadingIcon)
    }
}
