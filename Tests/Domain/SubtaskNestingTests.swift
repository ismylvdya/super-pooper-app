import Foundation
import Testing
@testable import SuperPooper

/// Subtasks stay under their parent in the pool, indented, whichever order the other tasks get.
struct SubtaskNestingTests {
    private let parent = makeTask("Move flat") { $0.timeEstimate = 240 }
    private let boxes = makeTask("Buy boxes") { $0.projects = ["Move flat"]; $0.timeEstimate = 2 }
    private let van = makeTask("Book a van") { $0.projects = ["move flat"]; $0.isHighPriority = true }
    private let other = makeTask("Pay rent") { $0.timeEstimate = 15 }

    @Test func subtasksFollowTheirParentIndented() {
        let plan = DayScenario(tasks: [boxes, other, van, parent]).build()
        #expect(plan.poolNames == ["Pay rent", "Move flat", "Book a van", "Buy boxes"])
        #expect(plan.pool.map(\.depth) == [0, 0, 1, 1])
    }

    @Test func aManualOrderDoesNotTearASubtaskFromItsParent() {
        var scenario = DayScenario(tasks: [boxes, other, van, parent])
        scenario.manualOrder = ["Buy boxes", "Pay rent", "Book a van", "Move flat"]
        #expect(scenario.build().poolNames == ["Pay rent", "Move flat", "Buy boxes", "Book a van"])
    }

    @Test func aSubtaskWhoseParentIsElsewhereStaysWhereItIs() {
        let plan = DayScenario(tasks: [boxes, other]).build()
        #expect(plan.poolNames == ["Buy boxes", "Pay rent"])
        #expect(plan.pool.map(\.depth) == [0, 0])
    }
}
