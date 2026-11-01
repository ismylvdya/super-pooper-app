import Foundation
import Testing
@testable import SuperPooperApp

/// One identity for a note's name everywhere: letter case does not matter, as in Obsidian links on Apple platforms. A
/// note renamed in Obsidian from "Drink water" to "Drink Water" keeps its place in every list that names it.
@Suite("Note names")
struct NoteNameTests {
    private let renamed = "Drink Water"
    private let written = "Drink water"

    @Test func namesMatchInAnyLetterCaseAndUnicodeForm() {
        #expect(NoteName("Drink Water") == NoteName("drink water"))
        #expect(NoteName("Caf\u{E9}") == NoteName("CAFE\u{301}"))
        #expect(NoteName("Drink Water") != NoteName("Drink Tea"))
    }

    @Test func theHabitListKeepsTheOrder() {
        let habits = [makeHabit("A"), makeHabit(renamed), makeHabit("B")]
        #expect(HabitOrder.sorted(habits, order: [written, "B"]).map(\.name) == [renamed, "B", "A"])
    }

    @Test func theRoutineKeepsTheOrder() {
        let water = makeHabit(renamed) { $0.habit.timeOfDay = .morning }
        let shower = makeHabit("Shower") { $0.habit.timeOfDay = .morning }
        #expect(HabitRoutines.members(.morning, of: [shower, water], order: [written, "Shower"]).map(\.name) == [renamed, "Shower"])
    }

    @Test func skipTodayAndNotTodayStillHoldTheNote() {
        let habit = makeHabit(renamed, status: .habit)
        let task = makeTask("Report")
        let plan = DayScenario(tasks: [habit, task], skipped: [written], postponed: ["report"]).build()
        #expect(plan.dayNames.isEmpty)
    }

    @Test func thePoolOrderKeepsTheTask() {
        let tasks = [makeTask("Alpha"), makeTask(renamed)]
        let plan = DayScenario(tasks: tasks, manualOrder: [written, "Alpha"]).build()
        #expect(plan.poolNames == [renamed, "Alpha"])
    }

    @Test func linksAndSubtasksFindTheNote() {
        let parent = makeTask(renamed)
        let child = makeTask("Child") { $0.projects = [written] }
        let after = makeTask("After") { $0.previousTasks = [written] }
        let graph = TaskGraph(tasks: [parent, child, after])
        #expect(graph.predecessors(of: "After") == [renamed])
        #expect(graph.missingLinks.isEmpty)
        let plan = DayScenario(tasks: [parent, child]).build()
        #expect(plan.pool.first { $0.id == "Child" }?.depth == 1)
        #expect(NameReferences.waiting(for: renamed, in: [parent, child, after]).map(\.name) == ["After"])
    }
}
