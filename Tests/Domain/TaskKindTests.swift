import Testing
@testable import SuperPooper

@Suite struct TaskKindTests {
    private let today = LocalDate(year: 2026, month: 10, day: 23)!

    private func note(status: TaskStatus = .thisWeek) -> TaskNote {
        TaskNote(name: "Water plants", relativePath: "TaskNotes/Tasks/Water plants.md", status: status)
    }

    @Test func taskBecomesDailyHabitKeepingItsTime() {
        var task = note()
        task.due = TaskDue(day: today, time: LocalTime(hour: 8, minute: 30))
        let changes = TaskKind.habit.changes(for: task, today: today)
        let result = task.applying(changes)
        #expect(result.status == .habit && result.isHabit)
        #expect(result.due == nil)
        #expect(result.habitTimes == [LocalTime(hour: 8, minute: 30)!])
        #expect(result.recurrenceRaw == "DTSTART:20261023T000000Z;FREQ=DAILY")
    }

    @Test func habitBecomesTaskWithoutRecurrenceOrReminders() {
        var habit = note(status: .habit)
        habit.recurrenceRaw = "DTSTART:20261001T000000Z;FREQ=DAILY"
        habit.reminderTimes = [LocalTime(hour: 9, minute: 0)!]
        let result = habit.applying(TaskKind.task.changes(for: habit, today: today))
        #expect(!result.isHabit && result.status == .thisWeek)
        #expect(result.reminderTimes.isEmpty)
    }

    @Test func switchingToTheCurrentKindChangesNothing() {
        #expect(TaskKind.task.changes(for: note(), today: today).isEmpty)
        #expect(TaskKind.habit.changes(for: note(status: .habit), today: today).isEmpty)
    }
}
