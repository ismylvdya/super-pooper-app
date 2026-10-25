#if DEBUG
import EventKit
import UIKit

/// DEBUG only: creates the "SuperPooper Test" calendar with today's demo events, a reminders list
/// with a 15:00 reminder, and an "Inbox" list the app must ignore. Re-running replaces them.
struct DemoDataSeeder {
    static let title = "SuperPooper Test"
    static let inboxTitle = "Inbox"

    struct Sources {
        let calendarID: String
        let reminderListID: String
    }

    let eventKit: EventKitAccess
    let calendar: Calendar
    let clock: Clock

    func seed() async -> Sources? {
        let hasEvents = await eventKit.requestAccess(for: .event)
        let hasReminders = await eventKit.requestAccess(for: .reminder)
        guard hasEvents, hasReminders else { return nil }
        let store = eventKit.store
        do {
            removeOld(in: store)
            let eventCalendar = try makeCalendar(.event, title: Self.title, color: .systemTeal, in: store)
            let today = LocalDate(clock.now, in: calendar)
            try addEvent("Morning sync", today, "10:00", "10:30", calendar: eventCalendar, store: store)
            try addEvent("Call with dad", today, "19:00", "20:00", calendar: eventCalendar, store: store)
            try addEvent("Day off", today, "00:00", "23:59", calendar: eventCalendar, store: store, allDay: true)
            try addEvent("Lunch", today, "13:00", "13:45", calendar: eventCalendar, store: store, recurring: true)

            let list = try makeCalendar(.reminder, title: Self.title, color: .systemOrange, in: store)
            try addReminder("Pick up the parcel", today, "15:00", list: list, store: store)
            let inbox = try makeCalendar(.reminder, title: Self.inboxTitle, color: .systemGray, in: store)
            try addReminder("Inbox thought: call the plumber", today, "11:00", list: inbox, store: store)
            try store.commit()
            return Sources(calendarID: eventCalendar.calendarIdentifier, reminderListID: list.calendarIdentifier)
        } catch {
            return nil
        }
    }

    private func removeOld(in store: EKEventStore) {
        for calendar in store.calendars(for: .event) where calendar.title == Self.title {
            try? store.removeCalendar(calendar, commit: false)
        }
        for list in store.calendars(for: .reminder) where [Self.title, Self.inboxTitle].contains(list.title) {
            try? store.removeCalendar(list, commit: false)
        }
        try? store.commit()
    }

    private func makeCalendar(_ type: EKEntityType, title: String, color: UIColor, in store: EKEventStore) throws -> EKCalendar {
        let calendar = EKCalendar(for: type, eventStore: store)
        calendar.title = title
        calendar.cgColor = color.cgColor
        let preferred = type == .event ? store.defaultCalendarForNewEvents?.source : store.defaultCalendarForNewReminders()?.source
        calendar.source = preferred ?? store.sources.first { $0.sourceType == .local } ?? store.sources.first
        try store.saveCalendar(calendar, commit: false)
        return calendar
    }

    private func date(_ day: LocalDate, _ time: String) -> Date {
        day.startDate(in: calendar, offset: LocalTime(string: time) ?? .midnight)
    }

    private func addEvent(_ title: String, _ day: LocalDate, _ start: String, _ end: String,
                          calendar eventCalendar: EKCalendar, store: EKEventStore, recurring: Bool = false, allDay: Bool = false) throws {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.calendar = eventCalendar
        event.startDate = date(day, start)
        event.endDate = date(day, end)
        event.isAllDay = allDay
        if recurring { event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)) }
        try store.save(event, span: .futureEvents, commit: false)
    }

    private func addReminder(_ title: String, _ day: LocalDate, _ time: String, list: EKCalendar, store: EKEventStore) throws {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = list
        let due = date(day, time)
        // No alarm: the app plans its own notifications, and an alarm already in the past would make
        // Reminders ring at once on every seeded launch (tests and screenshots launch dozens of times).
        reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        try store.save(reminder, commit: false)
    }
}
#endif
