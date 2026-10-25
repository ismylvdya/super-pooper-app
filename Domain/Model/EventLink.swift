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
