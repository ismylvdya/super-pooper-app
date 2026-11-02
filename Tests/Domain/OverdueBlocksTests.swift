import Foundation
import Testing
@testable import SuperPooperApp

/// An overdue timed block on today's timeline (its time has come, not marked) rides on the "now" cursor, as chain tasks do
/// (.1133): a task's, a repeatable task's or a habit's. Wednesday 2026-10-21; "now" is 13:25 unless a test says otherwise.
@Suite("Overdue blocks on the timeline")
@MainActor
struct OverdueBlocksTests {
    private func timed(_ name: String, at time: String, minutes: Int? = nil) -> TaskItem {
        makeTask(name) { $0.due = TaskDue("2026-10-21T\(time)"); $0.timeEstimate = minutes }
    }

    private func span(_ plan: DayPlan, _ name: String) throws -> String {
        let slot = try #require(plan.slot(name))
        return "\(clockTime(slot.start))–\(clockTime(slot.end))"
    }

    @Test func anOverdueTaskStandsAtNowAndKeepsItsTimeInTheNote() throws {
        let missed = timed("Missed at noon", at: "12:00")
        let plan = DayScenario(tasks: [missed]).build()
        #expect(try span(plan, "Missed at noon") == "13:25–13:40")
        #expect(plan.item(named: "Missed at noon")?.task.due == TaskDue("2026-10-21T12:00"))
        #expect(plan.slot("Missed at noon")?.time == LocalTime("12:00"), "still named by its own time (it can be dragged)")
    }

    @Test func itSlidesAlongWithNow() throws {
        let plan = DayScenario(tasks: [timed("Missed at noon", at: "12:00")]).build(at: TestCalendar.context(TestCalendar.wednesday, "17:10"))
        #expect(try span(plan, "Missed at noon") == "17:10–17:25")
    }

    /// Several overdue tasks stack from now in the order of their own times.
    @Test func overdueTasksStackInTheOrderOfTheirTimes() throws {
        let plan = DayScenario(tasks: [timed("At noon", at: "12:00", minutes: 15), timed("At eleven", at: "11:00", minutes: 60)]).build()
        #expect(try span(plan, "At eleven") == "13:25–14:25")
        #expect(try span(plan, "At noon") == "14:25–14:40")
    }

    /// A task still ahead and an event stay where they are; a done task leaves as before.
    @Test func onlyOpenBlocksWhoseTimeHasComeMove() throws {
        let later = timed("Later", at: "16:00", minutes: 60)
        let done = makeTask("Done at noon", status: .done) { $0.due = TaskDue("2026-10-21T12:00"); $0.completedDate = LocalDate("2026-10-21") }
        let standup = makeEvent("Standup", from: "10:00", to: "10:15")
        let evening = makeHabit("Evening walk", time: "18:00")
        let plan = DayScenario(tasks: [later, done, evening], events: [standup]).build()
        #expect(try span(plan, "Later") == "16:00–17:00")
        #expect(try span(plan, "Evening walk") == "18:00–18:15")
        #expect(plan.slot("Done at noon") == nil)
        #expect(plan.eventSlot("Standup").map { clockTime($0.start) } == "10:00")
    }

    // MARK: - Repeatable tasks and habits

    /// A repeatable task and a habit missed this morning ride on the cursor like a task, until marked; their notes keep
    /// their times.
    @Test func aMissedRepeatableTaskAndHabitRideOnTheCursor() throws {
        let vitamins = makeHabit("Vitamins", time: "09:00")
        let bins = makeHabit("Take out the bins", time: "10:00") { $0.habit.repeatable = true }
        let plan = DayScenario(tasks: [vitamins, bins]).build()
        #expect(try span(plan, "Vitamins") == "13:25–13:40")
        #expect(try span(plan, "Take out the bins") == "13:40–13:55")
        #expect(plan.slot("Vitamins")?.time == LocalTime("09:00"), "still named by its own time (it can be dragged)")
        #expect(plan.item(named: "Vitamins")?.task.due == TaskDue("2026-09-01T09:00"))

        let today = LocalDate(TestCalendar.wednesday)
        let marked = DayScenario(tasks: [vitamins.applying([.mark(.done, on: today)]), bins.applying([.mark(.done, on: today)])]).build()
        #expect(marked.timeline.isEmpty, "a mark closes the block")
    }

    /// Two missed blocks of one habit stack in their order with the other overdue blocks; Done closes the earliest, and
    /// the next one moves up to now.
    @Test func severalMissedBlocksStackInTheOrderOfTheirTimes() throws {
        let water = makeHabit("Water", status: .habit) { $0.reminderTimes = [LocalTime("09:00"), LocalTime("12:00"), LocalTime("18:00")] }
        let call = timed("Call", at: "11:00", minutes: 30)
        let plan = DayScenario(tasks: [water, call]).build()
        #expect(plan.timeline.map { "\(clockTime($0.start)) \($0.time?.description ?? "")" } == ["13:25 09:00", "13:40 11:00", "14:10 12:00", "18:00 18:00"])

        let done = DayScenario(tasks: [water.applying([.mark(.done, on: LocalDate(TestCalendar.wednesday))]), call]).build()
        #expect(done.timeline.map { "\(clockTime($0.start)) \($0.time?.description ?? "")" } == ["13:25 11:00", "13:55 12:00", "18:00 18:00"])
    }

    /// Today's drags of a habit block come first: a block dragged later is not overdue though its note's time has passed,
    /// and one dragged to a time that has come rides on the cursor in the order of that time.
    @Test func todaysHabitDragsComeFirst() throws {
        let vitamins = makeHabit("Vitamins", time: "09:00")
        let stretch = makeHabit("Stretch", time: "08:00")
        let moves = [TimeMove(task: "Vitamins", slot: LocalTime("09:00"), time: LocalTime("15:00")),
                     TimeMove(task: "Stretch", slot: LocalTime("08:00"), time: LocalTime("12:30"))]
        let plan = DayScenario(tasks: [vitamins, stretch, timed("At noon", at: "12:00")], timeMoves: moves).build()
        #expect(try span(plan, "Vitamins") == "15:00–15:15")
        #expect(try span(plan, "At noon") == "13:25–13:40")
        #expect(try span(plan, "Stretch") == "13:40–13:55")
        #expect(plan.slot("Stretch")?.time == LocalTime("08:00"))
    }

    /// What follows an overdue habit follows it from its place at now.
    @Test func aTaskAfterAnOverdueHabitFollowsIt() throws {
        let vitamins = makeHabit("Vitamins", time: "09:00")
        let after = makeTask("Afterwards") { $0.previousTasks = ["Vitamins"] }
        let plan = DayScenario(tasks: [vitamins, after]).build()
        #expect(try span(plan, "Afterwards") == "13:40–13:55")
    }

    /// What follows an overdue task follows it from its place at now.
    @Test func aTaskAfterAnOverdueOneFollowsIt() throws {
        let missed = timed("Missed at noon", at: "12:00", minutes: 60)
        let after = makeTask("Afterwards") { $0.previousTasks = ["Missed at noon"] }
        let plan = DayScenario(tasks: [missed, after]).build()
        #expect(try span(plan, "Missed at noon") == "13:25–14:25")
        #expect(try span(plan, "Afterwards") == "14:25–14:40")
    }

    /// Yesterday browsed on Today: its timeline has no "now", so a task of that day stays at its time.
    @Test func anotherDaysTasksStayAtTheirTimes() throws {
        let config = try AppConfig.load(bundle: .main)
        let yesterday = makeTask("Yesterday at ten") { $0.due = TaskDue("2026-10-20T10:00") }
        let plan = DayPlanning.plan(config: config, settings: TestConfig.defaults, tasks: [yesterday], events: [], reminders: [],
                                    dayState: DayState(day: LocalDate(TestCalendar.wednesday)), context: TestCalendar.context(),
                                    dayOffset: -1, eventsKnown: true)
        #expect(try span(plan, "Yesterday at ten") == "10:00–10:15")
    }
}
