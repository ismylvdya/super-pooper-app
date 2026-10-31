import Foundation

/// An event link as a note keeps it: `eventIdentifier|title|startISO8601` (the start with its offset).
enum EventLinkCodec {
    static let separator: Character = "|"

    /// The title may itself contain the separator, so only the first and the last ones split.
    static func parse(_ text: String) -> EventLink? {
        guard let first = text.firstIndex(of: separator), let last = text.lastIndex(of: separator), first < last else { return nil }
        let identifier = String(text[..<first])
        let title = String(text[text.index(after: first)..<last])
        let startText = String(text[text.index(after: last)...]).trimmingCharacters(in: .whitespaces)
        guard !identifier.isEmpty, let start = ISO8601.parse(startText) else { return nil }
        return EventLink(eventIdentifier: identifier, title: title, start: start)
    }

    static func format(_ link: EventLink, timeZone: TimeZone) -> String {
        let title = link.title.replacingOccurrences(of: "\n", with: " ")
        return [link.eventIdentifier, title, ISO8601.format(link.start, timeZone: timeZone)].joined(separator: String(separator))
    }
}
