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

    @Test func linksToTasksWithoutThatDateStillWork() {
        let screwdriver = makeTask("Find screwdriver")
        let assemble = makeTask("Assemble") { $0.due = TaskDue("2026-10-22"); $0.previousTasks = ["Find screwdriver"] }
        let plan = tomorrow([screwdriver, assemble])
        #expect(plan.problems(of: "Assemble").isEmpty)
        #expect(plan.item(named: "Assemble")?.isBlocked == true)
    }
}
