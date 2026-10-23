import Foundation
import Testing
@testable import SuperPooper

@Suite("Timeline edits and search")
struct TimelineEditsTests {
    @Test func allDayEventsGoToTheStripNotToTheTimeline() {
        let holiday = makeEvent("Holiday", from: "00:00", to: "23:59", allDay: true)
        let meeting = makeEvent("Meeting", from: "10:00", to: "11:00")
        let plan = DayScenario(tasks: [], events: [holiday, meeting]).build()
        #expect(plan.allDayEvents.map(\.title) == ["Holiday"])
        #expect(plan.eventSlot("Holiday") == nil)
        #expect(plan.eventSlot("Meeting") != nil)
    }

    @Test func searchMatchesNamesAndTitlesIgnoringCase() {
        let tasks = [makeTask("Buy Batteries"), makeTask("Call bank"), makeTask("batteries charger")]
        #expect(SearchMatcher.tasks(tasks, matching: "BATTER").map(\.name) == ["batteries charger", "Buy Batteries"])
        #expect(SearchMatcher.tasks(tasks, matching: "").isEmpty)
        let events = [makeEvent("Dentist", from: "10:00", to: "11:00"), makeEvent("Lunch", from: "12:00", to: "13:00")]
        #expect(SearchMatcher.events(events, matching: "lun").map(\.title) == ["Lunch"])
    }

    @Test func aReminderNotificationKnowsWhichReminderItCompletes() {
        let reminder = makeReminder("Call mum", at: "17:00")
        let planner = NotificationPlanner(horizonDays: 1, limit: 64)
        let planned = planner.plan(tasks: [], reminders: [reminder], skipped: [], context: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(planned.first?.reminderID == reminder.id)
    }

    @Test func tasksCanBeMarkedFromTheirLongPressMenu() {
        let menu = TestConfig.actions.actions(in: .taskContext).map(\.id)
        #expect(menu.contains(.done) && menu.contains(.unmark))
        #expect(TestConfig.actions.actions(in: .reminderNotification).map(\.id) == [.done])
    }
}
