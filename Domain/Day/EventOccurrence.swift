import Foundation

/// The occurrence of a calendar event an alert was made for. A repeating event shares its identifier with its other
/// occurrences, and an occurrence may have moved within its day since (D-013): the same identifier on the same logical
/// day, the nearest start. None when that day has no such event: another day's occurrence is never taken for it.
enum EventOccurrence {
    static func find(identifier: String, start: Date, in events: [CalendarEvent], context: DayContext) -> CalendarEvent? {
        let day = context.logicalDay(of: start)
        return events
            .filter { $0.eventIdentifier == identifier && context.logicalDay(of: $0.start) == day }
            .min { abs($0.start.timeIntervalSince(start)) < abs($1.start.timeIntervalSince(start)) }
    }
}
