import Foundation

/// Reference from a task to a calendar event: `eventIdentifier|title|startISO8601`.
/// Recurring events share one identifier, so the start pins the instance.
struct EventLink: Hashable, Codable, Sendable {
    static let separator: Character = "|"

    let eventIdentifier: String
    let title: String
    let start: Date

    init(eventIdentifier: String, title: String, start: Date) {
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.start = start
    }

    /// The title may itself contain the separator, so only the first and the last ones split.
    init?(rawValue: String) {
        guard let first = rawValue.firstIndex(of: EventLink.separator),
              let last = rawValue.lastIndex(of: EventLink.separator), first < last else { return nil }
        let identifier = String(rawValue[..<first])
        let title = String(rawValue[rawValue.index(after: first)..<last])
        let startText = String(rawValue[rawValue.index(after: last)...]).trimmingCharacters(in: .whitespaces)
        guard !identifier.isEmpty, let start = ISO8601.parse(startText) else { return nil }
        self.init(eventIdentifier: identifier, title: title, start: start)
    }

    func rawValue(timeZone: TimeZone) -> String {
        let sanitizedTitle = title.replacingOccurrences(of: "\n", with: " ")
        return [eventIdentifier, sanitizedTitle, ISO8601.format(start, timeZone: timeZone)]
            .joined(separator: String(EventLink.separator))
    }
}

/// ISO 8601 helpers shared by event links and TaskNotes timestamps.
enum ISO8601 {
    static func parse(_ text: String) -> Date? {
        for options in [ISO8601DateFormatter.Options.withInternetDateTime,
                        [.withInternetDateTime, .withFractionalSeconds]] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// `2026-10-23T19:00:00+02:00`
    static func format(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// TaskNotes `date_modified` style: `2026-10-22T18:01:02.456+02:00`.
    static func formatWithMilliseconds(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
