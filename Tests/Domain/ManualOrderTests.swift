import Foundation
import Testing
@testable import SuperPooper

/// The pool order the user dragged in the morning review (kept for today only).
/// Auto order of the base tasks: A (high priority), B (2 min), C (1 h).
@Suite("Manual pool order")
struct ManualOrderTests {
    private let context = TestCalendar.context(TestCalendar.wednesday, "10:00")
    private let a = makeTask("A") { $0.isHighPriority = true }
    private let b = makeTask("B") { $0.timeEstimate = 2 }
    private let c = makeTask("C") { $0.timeEstimate = 60 }

    @Test func baseTasksAutoSortAsADocumentedStartingPoint() {
        #expect(DayScenario(tasks: [c, b, a]).build(at: context).poolNames == ["A", "B", "C"])
    }

    @Test func knownTasksKeepTheUserOrder() {
        #expect(ordered(["C", "A", "B"], [a, b, c]) == ["C", "A", "B"])
    }

    @Test func propertyEditsDoNotBreakTheManualOrder() {
        let urgentB = b.applying([.highPriority(true), .due(TaskDue("2026-10-21")), .needEnergy(true)])
        let slowA = a.applying([.highPriority(false), .timeEstimate(240)])
        #expect(ordered(["C", "A", "B"], [slowA, urgentB, c]) == ["C", "A", "B"])
    }

    @Test func aNewTaskIsInsertedRightAfterItsAutoSortedNeighbour() {
        let energy = makeTask("N energy") { $0.needEnergy = true }
        #expect(DayScenario(tasks: [a, b, c, energy]).build(at: context).poolNames == ["A", "N energy", "B", "C"])
        #expect(ordered(["C", "B", "A"], [a, b, c, energy]) == ["C", "B", "A", "N energy"])
    }

    @Test func severalNewTasksEachFollowTheirOwnNeighbour() {
        let energy = makeTask("N energy") { $0.needEnergy = true }
        let halfHour = makeTask("N half hour") { $0.timeEstimate = 30 }
        #expect(ordered(["C", "B", "A"], [a, b, c, energy, halfHour]) == ["C", "B", "N half hour", "A", "N energy"])
    }

    @Test func aNewTaskThatSortsFirstGoesToTheTop() {
        let urgent = makeTask("Urgent") { $0.isHighPriority = true; $0.due = TaskDue("2026-10-21") }
        #expect(ordered(["C", "A", "B"], [a, b, c, urgent]) == ["Urgent", "C", "A", "B"])
    }

    @Test func namesThatAreNoLongerInThePoolAreIgnored() {
        #expect(ordered(["Gone", "C", "A", "Archived since", "B"], [a, b, c]) == ["C", "A", "B"])
    }

    @Test func theManualOrderCannotLiftATaskAboveItsPredecessor() {
        let dependent = b.applying([.addPreviousTask("A")])
        #expect(ordered(["B", "C", "A"], [a, dependent, c]) == ["C", "A", "B"])
    }

    @Test func doneTasksLeaveThePoolEvenWhenDraggedUp() {
        let doneC = makeTask("C", status: .done) { $0.completedDate = LocalDate("2026-10-21") }
        #expect(ordered(["C", "A", "B"], [a, b, doneC]) == ["A", "B"])
    }

    @Test func resetToAutoRestoresTheSortedOrder() {
        var scenario = DayScenario(tasks: [a, b, c], manualOrder: ["C", "B", "A"])
        #expect(scenario.build(at: context).poolNames == ["C", "B", "A"])
        scenario.manualOrder = nil
        #expect(scenario.build(at: context).poolNames == ["A", "B", "C"])
    }

    @Test func timelineTasksInTheManualOrderStayOnTheTimeline() {
        let timed = makeTask("Timed") { $0.due = TaskDue("2026-10-21T16:00") }
        let plan = DayScenario(tasks: [a, b, c, timed], manualOrder: ["Timed", "C", "B", "A"]).build(at: context)
        #expect(plan.poolNames == ["C", "B", "A"])
        #expect(plan.timelineTaskNames == ["Timed"])
    }

    private func ordered(_ manual: [String], _ tasks: [TaskNote]) -> [String] {
        DayScenario(tasks: tasks, manualOrder: manual).build(at: context).poolNames
    }
}
