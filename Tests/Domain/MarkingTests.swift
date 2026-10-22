import Foundation
import Testing
@testable import SuperPooper

/// Check-off marks (`<habits>` "Отметки", `<data_model>` `completed_date`). Today is 2026-10-21.
@Suite("Marks")
struct MarkingTests {
    private let today = LocalDate("2026-10-21")
    private var marking: TaskMarking { TaskMarking(today: today) }

    /// History: done on the 18th, partially on the 19th, twice on the 20th.
    private let habit = makeHabit("Meditation") { task in
        task.completeInstances = [LocalDate("2026-10-18"), LocalDate("2026-10-19"), LocalDate("2026-10-20")]
        task.partialInstances = [LocalDate("2026-10-19")]
        task.twiceInstances = [LocalDate("2026-10-20")]
    }

    // MARK: - Recurring tasks

    @Test func doneAddsTodayToCompleteInstancesOnly() {
        #expect(lists(after: .done) == List(complete: ["18", "19", "20", "21"], partial: ["19"], twice: ["20"]))
    }

    @Test func partiallyAddsTodayToCompleteAndPartialInstances() {
        #expect(lists(after: .partial) == List(complete: ["18", "19", "20", "21"], partial: ["19", "21"], twice: ["20"]))
    }

    @Test func twiceAddsTodayToCompleteAndTwiceInstances() {
        #expect(lists(after: .twice) == List(complete: ["18", "19", "20", "21"], partial: ["19"], twice: ["20", "21"]))
    }

    @Test(arguments: HabitMark.allCases, HabitMark.allCases)
    func switchingMarksRewritesOnlyTheExtraLists(from first: HabitMark, to second: HabitMark) {
        let marked = habit.applying(marking.changes(marking: habit, as: first))
        let switched = marked.applying(marking.changes(marking: marked, as: second))
        #expect(switched.completeInstances.filter { $0 == today }.count == 1)
        #expect(HabitInstances(task: switched).mark(on: today) == second)
        #expect(switched.partialInstances.contains(today) == (second == .partial))
        #expect(switched.twiceInstances.contains(today) == (second == .twice))
        #expect(List(switched).withoutToday == List(habit))
    }

    @Test(arguments: HabitMark.allCases)
    func unmarkingRemovesTodayFromAllThreeLists(mark: HabitMark) {
        let marked = habit.applying(marking.changes(marking: habit, as: mark))
        let unmarked = marked.applying(marking.changes(marking: marked, as: nil))
        #expect(List(unmarked) == List(habit))
    }

    @Test func settingTheSameMarkAgainChangesNothing() {
        let marked = habit.applying(marking.changes(marking: habit, as: .twice))
        #expect(marking.changes(marking: marked, as: .twice).isEmpty)
        #expect(marking.changes(marking: habit, as: nil).isEmpty)
    }

    @Test func tapTogglesBetweenDoneAndNoMark() {
        let done = habit.applying(marking.changes(toggling: habit))
        #expect(HabitInstances(task: done).mark(on: today) == .done)
        let partial = habit.applying(marking.changes(marking: habit, as: .partial))
        let cleared = partial.applying(marking.changes(toggling: partial))
        #expect(HabitInstances(task: cleared).mark(on: today) == nil)
        #expect(List(cleared) == List(habit))
    }

    @Test func recurringTasksNeverGetStatusOrCompletedDate() {
        for mark in HabitMark.allCases {
            for change in marking.changes(marking: habit, as: mark) {
                guard case .habitInstances = change else {
                    Issue.record("Unexpected change \(change) for \(mark)")
                    continue
                }
            }
        }
    }

    // MARK: - Regular tasks

    @Test func doneSetsStatusAndCompletedDate() {
        let task = makeTask("Pay for internet")
        #expect(marking.changes(marking: task, as: .done) == [.status(.done), .completedDate(today)])
        #expect(marking.changes(toggling: task) == [.status(.done), .completedDate(today)])
    }

    @Test func undoRevertsToThisWeekAndRemovesCompletedDate() {
        let done = makeTask("Buy milk", status: .done) { $0.completedDate = self.today }
        #expect(marking.changes(marking: done, as: nil) == [.status(.thisWeek), .completedDate(nil)])
        #expect(marking.changes(toggling: done) == [.status(.thisWeek), .completedDate(nil)])
        let reverted = done.applying(marking.changes(toggling: done))
        #expect(reverted.status == .thisWeek && reverted.completedDate == nil)
    }

    @Test func markingAnAlreadyDoneTaskOrUnmarkingAnOpenOneChangesNothing() {
        #expect(marking.changes(marking: makeTask("Done", status: .done), as: .done).isEmpty)
        #expect(marking.changes(marking: makeTask("Open"), as: nil).isEmpty)
    }

    // MARK: - Helpers

    private func lists(after mark: HabitMark) -> List {
        List(habit.applying(marking.changes(marking: habit, as: mark)))
    }

    /// The three instance lists as October day numbers, in file order.
    private struct List: Equatable {
        var complete: [String]
        var partial: [String]
        var twice: [String]

        init(complete: [String], partial: [String], twice: [String]) {
            self.complete = complete
            self.partial = partial
            self.twice = twice
        }

        init(_ task: TaskNote) {
            func days(_ list: [LocalDate]) -> [String] { list.map { String(format: "%02d", $0.day) } }
            self.init(complete: days(task.completeInstances), partial: days(task.partialInstances), twice: days(task.twiceInstances))
        }

        var withoutToday: List {
            List(complete: complete.filter { $0 != "21" }, partial: partial.filter { $0 != "21" }, twice: twice.filter { $0 != "21" })
        }
    }
}

struct StatusChangeTests {
    private let today = LocalDate(year: 2026, month: 10, day: 21)!

    @Test func settingDoneAddsCompletedDateAndLeavingRemovesIt() {
        let open = TaskNote(name: "Task", relativePath: "Task.md", status: .thisWeek)
        #expect(TaskMarking(today: today).changes(setting: .done, on: open) == [.status(.done), .completedDate(today)])
        var done = open
        done.status = .done
        done.completedDate = today
        #expect(TaskMarking(today: today).changes(setting: .halfYear, on: done) == [.status(.halfYear), .completedDate(nil)])
        #expect(TaskMarking(today: today).changes(setting: .done, on: done).isEmpty)
    }

    @Test func recurringTasksOnlyChangeStatus() {
        var habit = TaskNote(name: "Habit", relativePath: "Habit.md", status: .halfYear)
        habit.recurrenceRaw = "FREQ=DAILY"
        #expect(TaskMarking(today: today).changes(setting: .done, on: habit) == [.status(.done)])
    }
}
