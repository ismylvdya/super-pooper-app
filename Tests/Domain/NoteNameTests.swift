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

    @Test func skipTodayStillHoldsTheNote() {
        let habit = makeHabit(renamed, status: .habit)
        let task = makeTask("Report")
        let plan = DayScenario(tasks: [habit, task], skipped: [written]).build()
        #expect(plan.dayNames == ["Report"])
    }

    @Test func thePoolOrderKeepsTheTask() {
        let tasks = [makeTask("Alpha"), makeTask(renamed)]
        let plan = DayScenario(tasks: tasks, manualOrder: [written, "Alpha"]).build()
        #expect(plan.poolNames == [renamed, "Alpha"])
    }

}
