import Foundation
import Testing
@testable import SuperPooperApp

/// Wall-clock times ring at their clock time in whatever zone the phone is in; events, timed reminders and items with
/// a zone of their own ring at their moment. Planned in Belgrade on Wednesday 2026-10-21, checked as if the phone had
/// flown to Jakarta before they ring.
struct NotificationTriggerTests {
    private let planner = NotificationPlanner(horizonDays: TestConfig.rules.notifications.horizonDays,
                                              limit: TestConfig.rules.notifications.limit)
    private let jakarta = TestCalendar.calendar(in: "Asia/Jakarta")

    private func planned(tasks: [TaskNote] = [], reminders: [ReminderItem] = [], events: [CalendarEvent] = []) -> [PlannedNotification] {
        planner.plan(tasks: tasks, reminders: reminders, events: events, skipped: [], context: TestCalendar.context(TestCalendar.wednesday, "08:00"))
    }

    /// The moment the trigger fires once the phone is in Jakarta.
    private func firesInJakarta(_ notification: PlannedNotification) -> Date? {
        jakarta.date(from: NotificationTrigger.components(for: notification, calendar: TestCalendar.calendar))
    }

    @Test func aTaskWithoutAZoneRingsAtItsClockTimeAfterAFlight() throws {
        let task = makeTask("Call") { $0.due = TaskDue("2026-10-21T19:00") }
        let note = try #require(planned(tasks: [task]).first)
        #expect(!note.isAbsolute)
        #expect(firesInJakarta(note) == LocalDate("2026-10-21").startDate(in: jakarta, offset: LocalTime("19:00")))
    }

    @Test func eventsRemindersAndZonedItemsRingAtTheirMoment() throws {
        var event = makeEvent("Call with dad", from: "19:00", to: "20:00")
        event.alarmDates = [TestCalendar.date(TestCalendar.wednesday, "18:45")]
        let zoned = makeTask("Standup") { $0.due = TaskDue("2026-10-21T10:00"); $0.timeZone = "Europe/Belgrade" }
        let notes = planned(tasks: [zoned], reminders: [makeReminder("Pills", at: "12:00")], events: [event])
        #expect(notes.count == 3)
        for note in notes {
            #expect(note.isAbsolute)
            #expect(firesInJakarta(note) == note.fireDate)
        }
    }
}
