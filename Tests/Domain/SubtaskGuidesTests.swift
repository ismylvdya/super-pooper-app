import Foundation
import Testing
@testable import SuperPooperApp

/// The lines from a parent to its subtasks in the pool.
@Suite("Subtask guides")
struct SubtaskGuidesTests {
    private func item(_ name: String, depth: Int) -> DayItem {
        var item = DayItem(task: makeTask(name), state: .open, problems: [])
        item.depth = depth
        return item
    }

    @Test func theLineGoesOnPastASubtaskWithASubtaskOfItsOwnToTheNextSibling() {
        let guides = SubtaskGuides.guides(of: [
            item("Trip", depth: 0), item("Pack", depth: 1), item("Socks", depth: 2), item("Book", depth: 1), item("Read", depth: 0),
        ])
        #expect(guides["Trip"] == nil && guides["Read"] == nil)
        #expect(guides["Pack"] == SubtaskGuide(depth: 1, isLast: false, passes: []))
        #expect(guides["Socks"] == SubtaskGuide(depth: 2, isLast: true, passes: [true]))
        #expect(guides["Book"] == SubtaskGuide(depth: 1, isLast: true, passes: []))
    }

    @Test func aLastSubtasksOwnSubtaskHasNoLinePassingAbove() {
        let guides = SubtaskGuides.guides(of: [item("Trip", depth: 0), item("Pack", depth: 1), item("Socks", depth: 2)])
        #expect(guides["Socks"] == SubtaskGuide(depth: 2, isLast: true, passes: [false]))
    }
}
