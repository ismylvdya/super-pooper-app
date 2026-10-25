import Foundation
import Testing
@testable import SuperPooper

/// Another day browsed on Today (Thursday 2026-10-22, seen on Wednesday at 13:25): the same day rules,
/// with "past" and blocking measured from the real now, and links resolved among all tasks.
@Suite("Other days")
@MainActor
struct OtherDayTests {
    private let config: AppConfig
    private let call = makeEvent("Early call", day: "2026-10-22", from: "07:00", to: "07:30")

    init() throws {
        config = try AppConfig.load(bundle: .main)
    }

    private func tomorrow(_ tasks: [TaskNote], events: [CalendarEvent] = []) -> DayPlan {
        DayPlanning.plan(config: config, settings: TestConfig.defaults, tasks: tasks, events: events, reminders: [],
                         dayState: DayState(day: LocalDate(TestCalendar.wednesday)), context: TestCalendar.context(), dayOffset: 1)
    }

    @Test func tomorrowsEventsAreNotPastYet() throws {
        let plan = tomorrow([], events: [call])
        let slot = try #require(plan.eventSlot("Early call"))
        #expect(!slot.isPast)
    }

    @Test func aTaskAfterTomorrowsEventIsBlockedUntilItEnds() {
        let followUp = makeTask("Follow up") { $0.due = TaskDue("2026-10-22"); $0.previousEvent = eventLink(to: self.call) }
        #expect(tomorrow([followUp], events: [call]).item(named: "Follow up")?.isBlocked == true)
    }

    @Test func onlyThisWeeksTasksAreShown() {
        let waiting = makeTask("Waiting", status: .waiting) { $0.due = TaskDue("2026-10-22") }
        let planned = makeTask("Planned") { $0.due = TaskDue("2026-10-22") }
        #expect(tomorrow([waiting, planned]).dayNames == ["Planned"] as Set)
    }

    /// Habits come by their own repeat rule on the days ahead too, and only those shown in Today.
    @Test func habitsShowOnTheDaysTheyRepeat() {
        let everyDay = makeHabit("Water", status: .habit)
        let everySixDays = makeHabit("Laundry", rule: "DTSTART:20261021;FREQ=DAILY;INTERVAL=6", status: .habit)
        let hidden = makeHabit("Hidden", status: .habit) { $0.habit.showInToday = false }
        #expect(tomorrow([everyDay, everySixDays, hidden]).dayNames == ["Water"] as Set)
        let sixDaysOn = DayPlanning.plan(config: config, settings: TestConfig.defaults, tasks: [everyDay, everySixDays, hidden],
                                         events: [], reminders: [], dayState: DayState(day: LocalDate(TestCalendar.wednesday)),
                                         context: TestCalendar.context(), dayOffset: 6)
        #expect(sixDaysOn.dayNames == ["Water", "Laundry"] as Set)
    }

    @Test func linksToTasksWithoutThatDateStillWork() {
        let screwdriver = makeTask("Find screwdriver")
        let assemble = makeTask("Assemble") { $0.due = TaskDue("2026-10-22"); $0.previousTasks = ["Find screwdriver"] }
        let plan = tomorrow([screwdriver, assemble])
        #expect(plan.problems(of: "Assemble").isEmpty)
        #expect(plan.item(named: "Assemble")?.isBlocked == true)
    }
}
