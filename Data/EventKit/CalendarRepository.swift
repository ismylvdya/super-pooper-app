import EventKit
import UIKit

/// Anchor calendar events: read, plus the one edit the timeline offers (delete one occurrence).
protocol CalendarRepository: Sendable {
    var access: SourceAccess { get }
    func requestAccess() async -> Bool
    func calendars() -> [SourceCollection]
    func events(from start: Date, to end: Date, calendarIDs: [String]) async -> [CalendarEvent]
    /// Deletes this occurrence of an event (a recurring event keeps its other occurrences).
    func delete(_ event: CalendarEvent) async throws
    /// Calendar data changed, here or elsewhere; a burst of changes comes as several signals.
    func changes() -> AsyncStream<Void>
}

enum CalendarEditError: Error {
    case eventNotFound
}

struct EventKitCalendarRepository: CalendarRepository {
    let eventKit: EventKitAccess

    var access: SourceAccess { eventKit.access(for: .event) }

    func requestAccess() async -> Bool { await eventKit.requestAccess(for: .event) }

    func changes() -> AsyncStream<Void> { eventKit.changes() }

    func calendars() -> [SourceCollection] {
        guard access == .granted else { return [] }
        return eventKit.store.calendars(for: .event)
            .map(\.sourceCollection)
            .sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }
    }

    func delete(_ event: CalendarEvent) async throws {
        try await eventKit.write { store in
            let calendars = [store.calendar(withIdentifier: event.calendarID)].compactMap { $0 }
            let matches = store.events(matching: store.predicateForEvents(withStart: event.start, end: event.end, calendars: calendars))
            guard let found = matches.first(where: { $0.eventIdentifier == event.eventIdentifier && $0.startDate == event.start }) else {
                throw CalendarEditError.eventNotFound
            }
            try store.remove(found, span: .thisEvent)
        }
    }

    func events(from start: Date, to end: Date, calendarIDs: [String]) async -> [CalendarEvent] {
        guard access == .granted, !calendarIDs.isEmpty else { return [] }
        return await eventKit.read { store in
            let calendars = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
            guard !calendars.isEmpty else { return [] }
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
            return store.events(matching: predicate).compactMap(Self.event).sorted { $0.start < $1.start }
        }
    }

    private static func event(_ event: EKEvent) -> CalendarEvent? {
        guard let identifier = event.eventIdentifier, let start = event.startDate, let end = event.endDate else { return nil }
        return CalendarEvent(eventIdentifier: identifier, title: event.title ?? "", start: start, end: end,
                             isAllDay: event.isAllDay, calendarID: event.calendar.calendarIdentifier,
                             calendarTitle: event.calendar.title,
                             colorHex: UIColor(cgColor: event.calendar.cgColor).hexString,
                             hasAlarm: event.hasAlarms,
                             alarmDates: event.status == .canceled ? [] : (event.alarms ?? []).map { alarm in
                                 alarm.absoluteDate ?? start.addingTimeInterval(alarm.relativeOffset)
                             })
    }
}
