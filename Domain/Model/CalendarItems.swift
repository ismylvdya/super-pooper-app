import Foundation

/// A timed event from an anchor calendar (read-only).
struct CalendarEvent: Identifiable, Hashable, Codable, Sendable {
    let eventIdentifier: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarID: String
    let calendarTitle: String
    let colorHex: String

    /// Recurring instances share `eventIdentifier`; the start makes them unique.
    var id: String { "\(eventIdentifier)@\(start.timeIntervalSince1970)" }

    /// All-day events live on calendar days, not on the shifted logical day: the day must lie
    /// between the first day and the day of the last moment (the end is exclusive).
    func covers(_ day: LocalDate, calendar: Calendar) -> Bool {
        let first = LocalDate(start, in: calendar)
        let last = LocalDate(max(end.addingTimeInterval(-1), start), in: calendar)
        return first <= day && day <= last
    }
}

/// A "remember at X" reminder from a selected Reminders list (read-only).
struct ReminderItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let due: Date
    let listID: String
    let listTitle: String
    let colorHex: String
    let isCompleted: Bool
}

/// A calendar or a reminders list the user can pick as a source.
struct SourceCollection: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let colorHex: String
    let sourceTitle: String
}
