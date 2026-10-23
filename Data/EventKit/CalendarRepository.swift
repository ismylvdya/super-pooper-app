import EventKit
import UIKit

/// Anchor calendar events: read, plus the two edits the timeline offers (add an event, delete one occurrence).
protocol CalendarRepository: Sendable {
    var access: SourceAccess { get }
    func requestAccess() async -> Bool
    func calendars() -> [SourceCollection]
    func events(from start: Date, to end: Date, calendarIDs: [String]) -> [CalendarEvent]
    /// Adds an event to `calendarID` (nil = the default calendar for new events).
    func addEvent(title: String, start: Date, end: Date, calendarID: String?) throws
    /// Deletes this occurrence of an event (a recurring event keeps its other occurrences).
    func delete(_ event: CalendarEvent) throws
}

enum CalendarEditError: Error {
    case noCalendar
    case eventNotFound
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

    func addEvent(title: String, start: Date, end: Date, calendarID: String?) throws {
        let store = eventKit.store
        let calendar = calendarID.flatMap(store.calendar(withIdentifier:)).flatMap { $0.allowsContentModifications ? $0 : nil }
            ?? store.defaultCalendarForNewEvents
        guard let calendar else { throw CalendarEditError.noCalendar }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.calendar = calendar
        try store.save(event, span: .thisEvent)
    }

    func delete(_ event: CalendarEvent) throws {
        let store = eventKit.store
        let matches = store.events(matching: store.predicateForEvents(withStart: event.start, end: event.end,
                                                                      calendars: [store.calendar(withIdentifier: event.calendarID)].compactMap { $0 }))
        guard let found = matches.first(where: { $0.eventIdentifier == event.eventIdentifier && $0.startDate == event.start }) else {
            throw CalendarEditError.eventNotFound
        }
        try store.remove(found, span: .thisEvent)
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
