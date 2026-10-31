import Foundation
import Testing
@testable import SuperPooperApp

/// Check-off marks (`<habits>` "Отметки", `<data_model>` `completed_date`). Today is 2026-10-21.
@Suite("Marks")
struct MarkingTests {
    private let today = LocalDate("2026-10-21")
    private var marking: TaskMarking { TaskMarking(today: today) }

    /// History: done on the 18th, partially on the 19th, twice on the 20th.
    private let habit = makeHabit("Meditation") { task in
        task.marks = [LocalDate("2026-10-18"): .done, LocalDate("2026-10-19"): .partial, LocalDate("2026-10-20"): .twice]
    }

    // MARK: - Recurring tasks

    @Test(arguments: HabitMark.allCases)
    func aMarkSetsTodayAndKeepsTheHistory(mark: HabitMark) {
        #expect(marks(after: mark) == habit.marks.merging([today: mark]) { $1 })
    }

    @Test(arguments: HabitMark.allCases, HabitMark.allCases)
    func switchingMarksChangesOnlyToday(from first: HabitMark, to second: HabitMark) {
        let marked = habit.applying(marking.changes(marking: habit, as: first))
        let switched = marked.applying(marking.changes(marking: marked, as: second))
        #expect(switched.mark(on: today) == second)
        #expect(switched.marks.filter { $0.key != today } == habit.marks)
    }

    @Test(arguments: HabitMark.allCases)
    func unmarkingRemovesToday(mark: HabitMark) {
        let marked = habit.applying(marking.changes(marking: habit, as: mark))
        let unmarked = marked.applying(marking.changes(marking: marked, as: nil))
        #expect(unmarked.marks == habit.marks)
    }

    @Test func settingTheSameMarkAgainChangesNothing() {
        let marked = habit.applying(marking.changes(marking: habit, as: .twice))
        #expect(marking.changes(marking: marked, as: .twice).isEmpty)
        #expect(marking.changes(marking: habit, as: nil).isEmpty)
    }

    @Test func tapTogglesBetweenDoneAndNoMark() {
        let done = habit.applying(marking.changes(toggling: habit))
        #expect(done.mark(on: today) == .done)
        let partial = habit.applying(marking.changes(marking: habit, as: .partial))
        let cleared = partial.applying(marking.changes(toggling: partial))
        #expect(cleared.mark(on: today) == nil)
        #expect(cleared.marks == habit.marks)
    }

    @Test func recurringTasksNeverGetStatusOrCompletedDate() {
        for mark in HabitMark.allCases {
            for change in marking.changes(marking: habit, as: mark) {
                guard case .mark = change else {
                    Issue.record("Unexpected change \(change) for \(mark)")
                    continue
                }
            }
        }
    }

    // MARK: - Regular tasks

    @Test func doneSetsStatusAndCompletedDate() {
        let task = makeTask("Pay for internet")
        #expect(marking.changes(marking: task, as: .done) == [.complete(on: today)])
        #expect(marking.changes(toggling: task) == [.complete(on: today)])
    }

    @Test func undoRevertsToThisWeekAndRemovesCompletedDate() {
        let done = makeTask("Buy milk", status: .done) { $0.completedDate = self.today }
        #expect(marking.changes(marking: done, as: nil) == [.reopen])
        #expect(marking.changes(toggling: done) == [.reopen])
        let reverted = done.applying(marking.changes(toggling: done))
        #expect(reverted.status == .thisWeek && reverted.completedDate == nil)
    }

    @Test func markingAnAlreadyDoneTaskOrUnmarkingAnOpenOneChangesNothing() {
        #expect(marking.changes(marking: makeTask("Done", status: .done), as: .done).isEmpty)
        #expect(marking.changes(marking: makeTask("Open"), as: nil).isEmpty)
    }

    // MARK: - Helpers

    private func marks(after mark: HabitMark) -> [LocalDate: HabitMark] {
        habit.applying(marking.changes(marking: habit, as: mark)).marks
    }
}

struct StatusChangeTests {
    private let today = LocalDate(year: 2026, month: 10, day: 21)!

    @Test func settingDoneAddsCompletedDateAndLeavingRemovesIt() {
        let open = TaskItem(id: TaskID("Task.md"), name: "Task", status: .thisWeek)
        #expect(TaskMarking(today: today).changes(setting: .done, on: open) == [.complete(on: today)])
        var done = open
        done.status = .done
        done.completedDate = today
        #expect(TaskMarking(today: today).changes(setting: .halfYear, on: done) == [.status(.halfYear)])
        #expect(TaskMarking(today: today).changes(setting: .done, on: done).isEmpty)
    }

    @Test func anyStatusOtherThanDoneDropsTheDayOfCompletion() {
        var done = TaskItem(id: TaskID("Task.md"), name: "Task", status: .done)
        done.completedDate = today
        let changes = TaskMarking(today: today).changes(setting: .archived, on: done)
        #expect(changes == [.status(.archived)])
        let archived = done.applying(changes)
        #expect(archived.status == .archived && archived.completedDate == nil)
    }

    @Test func recurringTasksOnlyChangeStatus() {
        var habit = TaskItem(id: TaskID("Habit.md"), name: "Habit", status: .halfYear)
        habit.recurrence = try? RecurrenceCodec.parse("FREQ=DAILY").get()
        #expect(TaskMarking(today: today).changes(setting: .done, on: habit) == [.status(.done)])
    }
}
