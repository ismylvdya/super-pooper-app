import Foundation
import Testing
@testable import SuperPooperApp

/// Through the app's intents: a habit's subtask is created repeatable with the parent's rule, a task's stays a one-off
/// task, the parent's new rule reaches its repeatable subtasks, and Delete takes the subtask's note away for all days.
@MainActor
struct RepeatableSubtaskTests {
    private let habit = makeHabit("Утро — зарядка 🤸", rule: "DTSTART:20260901;FREQ=WEEKLY;BYDAY=MO,WE,FR", status: .habit)

    private func model(_ tasks: [TaskItem]) throws -> AppModel {
        try #require(PreviewModel.make(tasks: tasks, delay: NoDelay())).model
    }

    @Test func aHabitsSubtaskIsARepeatableTaskWithTheParentsRule() async throws {
        let model = try model([habit])
        await model.addSubtask("Отжимания", to: "Утро — зарядка 🤸")
        let subtask = try #require(model.task(named: "Отжимания"))
        #expect(subtask.isHabit && subtask.habit.repeatable)
        #expect(subtask.projects == ["Утро — зарядка 🤸"])
        #expect(subtask.recurrence == habit.recurrence)
        #expect(subtask.habit.showInToday == habit.habit.showInToday)
        #expect(model.isRepeatableSubtask(subtask))
    }

    @Test func aRepeatableTasksSubtaskIsRepeatableToo() async throws {
        var bills = habit
        bills.name = "Bills"
        bills.habit.repeatable = true
        bills.habit.showInToday = false
        let model = try model([bills])
        await model.addSubtask("Electricity", to: "Bills")
        let subtask = try #require(model.task(named: "Electricity"))
        #expect(subtask.isHabit && subtask.habit.repeatable && !subtask.habit.showInToday)
    }

    @Test func aTasksSubtaskIsStillAOneOffTask() async throws {
        let model = try model([makeTask("Renovation")])
        await model.addSubtask("Paint", to: "Renovation")
        let subtask = try #require(model.task(named: "Paint"))
        #expect(!subtask.isHabit && subtask.status == .thisWeek && subtask.projects == ["Renovation"])
        #expect(!model.isRepeatableSubtask(subtask))
    }

    @Test func aNewHabitsSubtasksAreRepeatable() async throws {
        let model = try model([])
        var draft = model.newHabitDraft()
        draft.subtasks = ["Stretch"]
        _ = await model.create(draft, named: "Yoga")
        let subtask = try #require(model.task(named: "Stretch"))
        #expect(subtask.isHabit && subtask.recurrence == model.task(named: "Yoga")?.recurrence)
    }

    @Test func aNewParentRuleIsWrittenToItsRepeatableSubtasks() async throws {
        let model = try model([habit])
        await model.addSubtask("Отжимания", to: "Утро — зарядка 🤸")
        await model.addSubtask("Ещё десять", to: "Отжимания")
        let daily = try RecurrenceCodec.parse("DTSTART:20260901;FREQ=DAILY").get()
        await model.update("Утро — зарядка 🤸", [.recurrence(daily)])
        #expect(model.task(named: "Отжимания")?.recurrence == daily)
        #expect(model.task(named: "Ещё десять")?.recurrence == daily)
    }

    @Test func aOneOffSubtaskKeepsNoRule() async throws {
        let oneOff = makeTask("Купить коврик") { $0.projects = ["Утро — зарядка 🤸"] }
        let model = try model([habit, oneOff])
        await model.update("Утро — зарядка 🤸", [.recurrence(try RecurrenceCodec.parse("DTSTART:20260901;FREQ=DAILY").get())])
        #expect(model.task(named: "Купить коврик")?.recurrence == nil)
    }

    @Test func aParentsRuleRemovedLeavesTheSubtasksRule() async throws {
        let model = try model([habit])
        await model.addSubtask("Отжимания", to: "Утро — зарядка 🤸")
        await model.update("Утро — зарядка 🤸", [.recurrence(nil)])
        #expect(model.task(named: "Отжимания")?.recurrence == habit.recurrence)
    }

    @Test func deletingARepeatableSubtaskDeletesItsNote() async throws {
        let model = try model([habit])
        await model.addSubtask("Отжимания", to: "Утро — зарядка 🤸")
        await model.perform(.delete, on: "Отжимания")
        #expect(model.task(named: "Отжимания") == nil)
        #expect(model.task(named: "Утро — зарядка 🤸") != nil)
    }
}
