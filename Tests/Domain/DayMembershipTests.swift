import Foundation
import Testing
@testable import SuperPooperApp

/// What gets into today (`<day_logic>` "В день попадают"). Wednesday 2026-10-21, 13:25, day boundary 04:00.
@Suite("Day membership")
struct DayMembershipTests {
    // MARK: - Regular tasks

    @Test func thisWeekTasksAreInTheDay() {
        let plan = DayScenario(tasks: [makeTask("Week task")]).build()
        #expect(plan.poolNames == ["Week task"])
    }


    /// A task of Soon or Someday dated today comes into the pool on its day and stays in its list; an archived one does not.
    @Test(arguments: [TaskStatus.halfYear, .someday])
    func aLaterLevelsTaskComesOnItsDay(status: TaskStatus) {
        let task = makeTask("Backlog", status: status) { $0.due = TaskDue("2026-10-21") }
        #expect(DayScenario(tasks: [task]).build().poolNames == ["Backlog"])
        #expect(DayScenario(tasks: [makeTask("Undated", status: status)]).build().dayNames.isEmpty)
    }

    @Test func anArchivedTaskStaysOutOfTheDay() {
        let task = makeTask("Backlog", status: .archived) { $0.due = TaskDue("2026-10-21") }
        #expect(DayScenario(tasks: [task]).build().dayNames.isEmpty)
    }

    @Test func aTaskDoneTodayLeavesTheDay() {
        let task = makeTask("Done today", status: .done) { $0.completedDate = LocalDate("2026-10-21") }
        #expect(DayScenario(tasks: [task]).build().dayNames.isEmpty)
    }

    @Test func aTaskDoneEarlierOrWithoutCompletionDateIsHidden() {
        let yesterday = makeTask("Done yesterday", status: .done) { $0.completedDate = LocalDate("2026-10-20") }
        let undated = makeTask("Done undated", status: .done)
        #expect(DayScenario(tasks: [yesterday, undated]).build().dayNames.isEmpty)
    }

    /// A task dated an earlier day that was not done stays in the pool every day until it is handled.
    @Test(arguments: ["2026-10-20", "2026-10-14T09:00"])
    func anOverdueTaskStaysInThePool(due: String) {
        let task = makeTask("Overdue") { $0.due = TaskDue(due) }
        #expect(DayScenario(tasks: [task]).build().poolNames == ["Overdue"])
    }

    // MARK: - Recurring tasks

    /// Any status but `archived`: archiving takes a recurring task out of the day (see `ArchivedNotesTests`).
    @Test(arguments: [TaskStatus.thisWeek, .halfYear, .someday, .done, .habit])
    func recurringTasksFollowTheirRuleRegardlessOfStatus(status: TaskStatus) {
        let daily = makeHabit("Daily", status: status)
        let saturdays = makeHabit("Saturdays", rule: "DTSTART:20260905;FREQ=WEEKLY;BYDAY=SA", status: status)
        let scenario = DayScenario(tasks: [daily, saturdays])
        #expect(scenario.build().dayNames == ["Daily"])
        #expect(scenario.build(at: TestCalendar.context("2026-10-24", "10:00")).dayNames == ["Daily", "Saturdays"])
    }

    @Test func aRecurringTaskOutsideItsRuleWindowIsHidden() {
        let notYet = makeHabit("Starts Friday", rule: "DTSTART:20261023;FREQ=DAILY")
        let finished = makeHabit("Ended Monday", rule: "DTSTART:20261001;FREQ=DAILY;UNTIL=20261019")
        let everyThird = makeHabit("Every third day", rule: "DTSTART:20261019;FREQ=DAILY;INTERVAL=3")
        #expect(DayScenario(tasks: [notYet, finished, everyThird]).build().dayNames.isEmpty)
    }

    @Test func skipTodayHidesTheHabitForTheRestOfTheDay() {
        let scenario = DayScenario(tasks: [makeHabit("Water"), makeHabit("Timed", time: "18:00")], skipped: ["Water", "Timed"])
        #expect(scenario.build().dayNames.isEmpty)
    }

    @Test func aHabitMarkedTodayLeavesTheDay() {
        let habit = makeHabit("Meditation") { task in
            task.marks = [LocalDate("2026-10-20"): .twice, LocalDate("2026-10-21"): .partial]
        }
        #expect(DayScenario(tasks: [habit]).build().dayNames.isEmpty)
    }

    @Test func aTwiceADayHabitStaysUntilItsSecondMark() throws {
        let once = makeHabit("Brush teeth") { task in
            task.habit.twiceADay = true
            task.marks = [LocalDate("2026-10-21"): .done]
        }
        let item = try #require(DayScenario(tasks: [once]).build().item(named: "Brush teeth"))
        #expect(item.state == .marked(.done))
        var twice = once
        twice.marks = [LocalDate("2026-10-21"): .twice]
        #expect(DayScenario(tasks: [twice]).build().dayNames.isEmpty)
    }

    @Test func anUnknownRuleIsVisibleWithAProblem() throws {
        let unknown = makeHabit("Hourly", rule: "FREQ=HOURLY;INTERVAL=2") { $0.problems = [.unknownRecurrence("FREQ=HOURLY;INTERVAL=2")] }
        #expect(unknown.recurrence == nil)
        let plan = DayScenario(tasks: [unknown]).build()
        #expect(plan.poolNames == ["Hourly"])
        #expect(plan.problems(of: "Hourly") == [.unknownRecurrence("FREQ=HOURLY;INTERVAL=2")])
    }

    // MARK: - Problems


    /// Not today: the task leaves the pool and keeps its date (a deadline) and its list.
    @Test func notTodayTakesTheMarkAndKeepsTheDate() {
        let context = TestCalendar.context()
        let dated = makeTask("Dated", status: .someday) { $0.due = TaskDue(day: context.today.adding(days: -2)) }
        #expect(dated.isInTodayPool, "the day's turn brought it in")
        let moved = dated.applying(NotToday.changes(for: dated, context: context))
        #expect(moved.due == dated.due && moved.status == .someday && !moved.isInTodayPool)
        #expect(DayScenario(tasks: [moved]).build().item(named: "Dated") == nil)
    }

    /// Not today on a task with a time today: the same time tomorrow.
    @Test func notTodayMovesATimedTaskToTomorrow() {
        let context = TestCalendar.context()
        let timed = makeTask("Timed") { $0.due = TaskDue(day: context.today, time: LocalTime(string: "16:30")) }
        let moved = timed.applying(NotToday.changes(for: timed, context: context))
        #expect(moved.due == TaskDue(day: context.today.adding(days: 1), time: LocalTime(string: "16:30")))
        #expect(DayScenario(tasks: [moved]).build().item(named: "Timed") == nil)
    }

    /// Only the mark brings a task into today's pool: one put off (no mark) is not among today's, whatever its date.
    @Test func onlyTheMarkBringsATaskIntoThePool() {
        let today = TestCalendar.context().today
        let waiting = makeTask("Waits", inPool: false)
        let putOff = makeTask("Put off", inPool: false) { $0.due = TaskDue(day: today) }
        let soon = makeTask("From Soon", status: .halfYear) { $0.due = TaskDue(day: today) }
        let names = DayScenario(tasks: [waiting, putOff, soon, makeTask("Stays")]).build().poolNames
        #expect(Set(names) == ["From Soon", "Stays"])
    }
}
