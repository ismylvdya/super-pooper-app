import Foundation
import Testing
@testable import SuperPooperApp

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
        #expect(plan.pool.map(\.hasSubtasks) == [false, true, false, false])
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

/// Subtasks dragged on the parent's page: the new places are written to the subtasks and the pool follows them.
struct SubtaskOrderTests {
    private func subtask(_ name: String, _ order: Int? = nil) -> TaskNote {
        makeTask(name) { $0.projects = ["Move flat"]; $0.subtaskOrder = order }
    }

    @Test func placedSubtasksComeFirstTheRestByName() {
        let sorted = SubtaskOrder.sorted([subtask("Call movers"), subtask("Pack books", 1), subtask("Buy boxes"), subtask("Book a van", 0)])
        #expect(sorted.map(\.name) == ["Book a van", "Pack books", "Buy boxes", "Call movers"])
    }

    @Test func aDroppedSubtaskTakesTheTargetsPlace() {
        let subtasks = [subtask("Book a van"), subtask("Buy boxes"), subtask("Call movers")]
        #expect(SubtaskOrder.moving("Call movers", onto: "Book a van", in: subtasks)
                == ["Call movers": 0, "Book a van": 1, "Buy boxes": 2])
        let placed = [subtask("Book a van", 0), subtask("Buy boxes", 1), subtask("Call movers", 2)]
        #expect(SubtaskOrder.moving("Book a van", onto: "Buy boxes", in: placed) == ["Buy boxes": 0, "Book a van": 1])
        #expect(SubtaskOrder.moving("Book a van", onto: "Book a van", in: placed).isEmpty)
    }

    @Test func thePoolFollowsTheOrderSetOnThePage() {
        let parent = makeTask("Move flat") { $0.timeEstimate = 240 }
        let van = makeTask("Book a van") { $0.projects = ["Move flat"]; $0.isHighPriority = true; $0.subtaskOrder = 1 }
        let boxes = makeTask("Buy boxes") { $0.projects = ["Move flat"]; $0.subtaskOrder = 0 }
        #expect(DayScenario(tasks: [van, boxes, parent]).build().poolNames == ["Move flat", "Buy boxes", "Book a van"])
    }
}
