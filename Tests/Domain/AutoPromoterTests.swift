import Foundation
import Testing
@testable import SuperPooper

/// Auto-promotion to `this_week` (`<day_logic>` "Автоперевод"): backlog tasks whose `due` falls between
/// today and Sunday. The week is Monday 2026-10-19 … Sunday 2026-10-25.
@Suite("Auto-promotion")
struct AutoPromoterTests {
    private let promoter = AutoPromoter(promotableStatuses: Set(TestConfig.rules.day.autoPromoteFrom.map(TestConfig.mapping.status(fromRaw:))))

    @Test func theConfigPromotesHalfYearAndSomeday() {
        #expect(promoter.promotableStatuses == [.halfYear, .someday])
    }

    @Test(arguments: ["2026-10-21", "2026-10-22T09:00", "2026-10-23", "2026-10-25", "2026-10-25T23:30"])
    func backlogTasksDueFromTodayThroughSundayArePromoted(due: String) {
        let halfYear = makeTask("Half year", status: .halfYear) { $0.due = TaskDue(due) }
        let someday = makeTask("Someday", status: .someday) { $0.due = TaskDue(due) }
        #expect(names(promoter.candidates(in: [halfYear, someday], context: TestCalendar.context())) == ["Half year", "Someday"])
    }

    @Test(arguments: ["2026-10-20", "2026-10-26", "2026-11-04"])
    func dueInThePastOrNextWeekIsNotPromoted(due: String) {
        let task = makeTask("Backlog", status: .halfYear) { $0.due = TaskDue(due) }
        #expect(promoter.candidates(in: [task], context: TestCalendar.context()).isEmpty)
    }

    @Test(arguments: [TaskStatus.thisWeek, .waiting, .done, .archived, .other("custom")])
    func otherStatusesAreNeverTouched(status: TaskStatus) {
        let task = makeTask("Task", status: status) { $0.due = TaskDue("2026-10-22") }
        #expect(promoter.candidates(in: [task], context: TestCalendar.context()).isEmpty)
    }

    @Test func recurringTasksAndTasksWithoutDueAreNotPromoted() {
        let habit = makeHabit("Habit", status: .halfYear) { $0.due = TaskDue("2026-10-22T09:00") }
        let undated = makeTask("Undated", status: .someday)
        #expect(promoter.candidates(in: [habit, undated], context: TestCalendar.context()).isEmpty)
    }

    @Test func onSundayOnlySundayIsLeftAndMondayBelongsToNextWeek() {
        let sunday = makeTask("Sunday", status: .halfYear) { $0.due = TaskDue("2026-10-25") }
        let monday = makeTask("Monday", status: .halfYear) { $0.due = TaskDue("2026-10-26") }
        let tasks = [sunday, monday]
        #expect(names(promoter.candidates(in: tasks, context: TestCalendar.context("2026-10-25", "18:00"))) == ["Sunday"])
        #expect(names(promoter.candidates(in: tasks, context: TestCalendar.context("2026-10-26", "03:00"))) == ["Sunday"])
        #expect(names(promoter.candidates(in: tasks, context: TestCalendar.context("2026-10-26", "09:00"))) == ["Monday"])
    }

    private func names(_ tasks: [TaskNote]) -> [String] { tasks.map(\.name) }
}
