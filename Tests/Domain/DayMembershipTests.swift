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

    @Test func aTaskDoneTodayStaysVisibleAsDone() throws {
        let task = makeTask("Done today", status: .done) { $0.completedDate = LocalDate("2026-10-21") }
        let item = try #require(DayScenario(tasks: [task]).build().item(named: "Done today"))
        #expect(item.isDone)
        #expect(item.state == .marked(.done))
    }

    @Test func aTaskDoneEarlierOrWithoutCompletionDateIsHidden() {
        let yesterday = makeTask("Done yesterday", status: .done) { $0.completedDate = LocalDate("2026-10-20") }
        let undated = makeTask("Done undated", status: .done)
        #expect(DayScenario(tasks: [yesterday, undated]).build().dayNames.isEmpty)
    }

    @Test func doneTodayIsStillVisibleAfterMidnightUntilTheDayBoundary() {
        let task = makeTask("Done Wednesday", status: .done) { $0.completedDate = LocalDate("2026-10-21") }
        let scenario = DayScenario(tasks: [task])
        #expect(scenario.build(at: TestCalendar.context("2026-10-22", "03:59")).poolNames == ["Done Wednesday"])
        #expect(scenario.build(at: TestCalendar.context("2026-10-22", "04:00")).poolNames.isEmpty)
    }

    // MARK: - Recurring tasks

    @Test(arguments: [TaskStatus.thisWeek, .halfYear, .someday, .waiting, .done, .archived])
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

    @Test func aMarkedHabitIsShownWithItsMark() throws {
        let habit = makeHabit("Meditation") { task in
            task.completeInstances = [LocalDate("2026-10-20"), LocalDate("2026-10-21")]
            task.partialInstances = [LocalDate("2026-10-21")]
            task.twiceInstances = [LocalDate("2026-10-20")]
        }
        let item = try #require(DayScenario(tasks: [habit]).build().item(named: "Meditation"))
        #expect(item.state == .marked(.partial))
        #expect(item.isDone)
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
