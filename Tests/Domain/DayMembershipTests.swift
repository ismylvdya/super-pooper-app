import Foundation
import Testing
@testable import SuperPooper

/// What gets into today (`<day_logic>` "В день попадают"). Wednesday 2026-10-21, 13:25, day boundary 04:00.
@Suite("Day membership")
struct DayMembershipTests {
    // MARK: - Regular tasks

    @Test func thisWeekTasksAreInTheDay() {
        let plan = DayScenario(tasks: [makeTask("Week task")]).build()
        #expect(plan.poolNames == ["Week task"])
    }

    @Test(arguments: [TaskStatus.halfYear, .someday, .waiting, .archived, .other("in_progress")])
    func otherStatusesStayOutOfTheDay(status: TaskStatus) {
        let task = makeTask("Backlog", status: status) { $0.due = TaskDue("2026-10-21") }
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

    @Test func notTodayMovesATimedTaskToTheSameTimeTomorrow() {
        let marking = TaskMarking(today: LocalDate("2026-10-21"))
        let timed = makeTask("Timed") { $0.due = TaskDue("2026-10-21T16:30") }
        let dated = makeTask("Dated") { $0.due = TaskDue("2026-10-21") }
        #expect(marking.notTodayChanges(for: timed) == [.due(TaskDue("2026-10-22T16:30"))])
        #expect(marking.notTodayChanges(for: dated).isEmpty)
    }

    // MARK: - Recurring tasks

    /// Any status but `archived`: archiving takes a recurring task out of the day (see `ArchivedNotesTests`).
    @Test(arguments: [TaskStatus.thisWeek, .halfYear, .someday, .waiting, .done, .habit])
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
            task.completeInstances = [LocalDate("2026-10-20"), LocalDate("2026-10-21")]
            task.partialInstances = [LocalDate("2026-10-21")]
            task.twiceInstances = [LocalDate("2026-10-20")]
        }
        #expect(DayScenario(tasks: [habit]).build().dayNames.isEmpty)
    }

    @Test func aTwiceADayHabitStaysUntilItsSecondMark() throws {
        let once = makeHabit("Brush teeth") { task in
            task.habit.twiceADay = true
            task.completeInstances = [LocalDate("2026-10-21")]
        }
        let item = try #require(DayScenario(tasks: [once]).build().item(named: "Brush teeth"))
        #expect(item.state == .marked(.done))
        var twice = once
        twice.twiceInstances = [LocalDate("2026-10-21")]
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

    @Test func missingLinksAndCyclesAreReportedOnTheTasks() {
        let missing = makeTask("Missing link") { $0.previousTasks = ["Nowhere"] }
        let first = makeTask("Cycle A") { $0.previousTasks = ["Cycle B"] }
        let second = makeTask("Cycle B") { $0.previousTasks = ["Cycle A"] }
        let plan = DayScenario(tasks: [missing, first, second]).build()
        #expect(plan.problems(of: "Missing link") == [.linkedTaskNotFound("Nowhere")])
        #expect(plan.problems(of: "Cycle A") == [.dependencyCycle])
        #expect(plan.problems(of: "Cycle B") == [.dependencyCycle])
        #expect(plan.dayNames == ["Missing link", "Cycle A", "Cycle B"])
    }

    @Test func linksResolveIgnoringLetterCase() {
        let task = makeTask("Follow-up") { $0.previousTasks = ["купить батарейки"] }
        let plan = DayScenario(tasks: [task, makeTask("Купить батарейки")]).build()
        #expect(plan.problems.isEmpty)
        #expect(plan.item(named: "Follow-up")?.blockers == [.task("Купить батарейки")])
    }
}
