import Foundation
import Testing
@testable import SuperPooperApp

/// An overdue timed task on today's timeline (its time has come, not done) rides on the "now" cursor, as chain tasks do
/// (.1133). Wednesday 2026-10-21; "now" is 13:25 unless a test says otherwise.
@Suite("Overdue tasks on the timeline")
@MainActor
struct OverdueTasksTests {
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
        #expect(plan.slot("Missed at noon")?.alerts == false, "its alert is over")
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

    /// Habits keep their slots; a task still ahead and an event stay where they are; a done task leaves as before.
    @Test func onlyOpenTasksWhoseTimeHasComeMove() throws {
        let vitamins = makeHabit("Vitamins", time: "09:00")
        let later = timed("Later", at: "16:00", minutes: 60)
        let done = makeTask("Done at noon", status: .done) { $0.due = TaskDue("2026-10-21T12:00"); $0.completedDate = LocalDate("2026-10-21") }
        let standup = makeEvent("Standup", from: "10:00", to: "10:15")
        let plan = DayScenario(tasks: [vitamins, later, done], events: [standup]).build()
        #expect(try span(plan, "Vitamins") == "09:00–09:15")
        #expect(try span(plan, "Later") == "16:00–17:00")
        #expect(plan.slot("Done at noon") == nil)
        #expect(plan.eventSlot("Standup").map { clockTime($0.start) } == "10:00")
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
