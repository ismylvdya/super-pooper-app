import EventKit
import UIKit

/// Read-only access to anchor calendar events.
protocol CalendarRepository: Sendable {
    var access: SourceAccess { get }
    func requestAccess() async -> Bool
    func calendars() -> [SourceCollection]
    func events(from start: Date, to end: Date, calendarIDs: [String]) -> [CalendarEvent]
}

struct EventKitCalendarRepository: CalendarRepository {
    let eventKit: EventKitAccess

    var access: SourceAccess { eventKit.access(for: .event) }

    func requestAccess() async -> Bool { await eventKit.requestAccess(for: .event) }

    func calendars() -> [SourceCollection] {
        guard access == .granted else { return [] }
        return eventKit.store.calendars(for: .event)
            .map(\.sourceCollection)
            .sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }
    }

    func events(from start: Date, to end: Date, calendarIDs: [String]) -> [CalendarEvent] {
        guard access == .granted, !calendarIDs.isEmpty else { return [] }
        let calendars = eventKit.store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = eventKit.store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return eventKit.store.events(matching: predicate).compactMap { event -> CalendarEvent? in
            guard let identifier = event.eventIdentifier, let start = event.startDate, let end = event.endDate else { return nil }
            return CalendarEvent(eventIdentifier: identifier, title: event.title ?? "", start: start, end: end,
                                 isAllDay: event.isAllDay, calendarID: event.calendar.calendarIdentifier,
                                 calendarTitle: event.calendar.title,
                                 colorHex: UIColor(cgColor: event.calendar.cgColor).hexString)
        }
        .sorted { $0.start < $1.start }
    }
}
