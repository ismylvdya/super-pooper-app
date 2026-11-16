import Foundation
import Testing
@testable import SuperPooperApp

/// Through the app's intents: the subtask of a habit or of a repeatable task is a task, as any task's is.
@MainActor
struct HabitSubtaskTests {
    private let habit = makeHabit("Утро — зарядка 🤸", rule: "DTSTART:20260901;FREQ=WEEKLY;BYDAY=MO,WE,FR", status: .habit)

    private func model(_ tasks: [TaskItem]) throws -> AppModel {
        try #require(PreviewModel.make(tasks: tasks, delay: NoDelay())).model
    }

    @Test func aHabitsSubtaskIsATask() async throws {
        let model = try model([habit])
        await model.addSubtask("Отжимания", to: "Утро — зарядка 🤸")
        let subtask = try #require(model.task(named: "Отжимания"))
        #expect(!subtask.isHabit && subtask.status == .thisWeek && subtask.recurrence == nil)
        #expect(subtask.projects == ["Утро — зарядка 🤸"])
    }

    @Test func aRepeatableTasksSubtaskIsATaskToo() async throws {
        var bills = habit
        bills.name = "Bills"
        bills.habit.repeatable = true
        let model = try model([bills])
        await model.addSubtask("Rent", to: "Bills")
        let subtask = try #require(model.task(named: "Rent"))
        #expect(!subtask.isHabit && subtask.projects == ["Bills"])
    }
}
