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
    /// The event has an alert in Calendar (its block shows the bell).
    var hasAlarm = false

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

extension CalendarEvent {
    private enum CodingKeys: String, CodingKey {
        case eventIdentifier, title, start, end, isAllDay, calendarID, calendarTitle, colorHex, hasAlarm
    }

    /// Widget snapshots written before `hasAlarm` existed still decode.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(eventIdentifier: try values.decode(String.self, forKey: .eventIdentifier),
                  title: try values.decode(String.self, forKey: .title),
                  start: try values.decode(Date.self, forKey: .start), end: try values.decode(Date.self, forKey: .end),
                  isAllDay: try values.decode(Bool.self, forKey: .isAllDay),
                  calendarID: try values.decode(String.self, forKey: .calendarID),
                  calendarTitle: try values.decode(String.self, forKey: .calendarTitle),
                  colorHex: try values.decode(String.self, forKey: .colorHex),
                  hasAlarm: try values.decodeIfPresent(Bool.self, forKey: .hasAlarm) ?? false)
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
