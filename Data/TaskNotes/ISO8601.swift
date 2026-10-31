import Foundation

/// ISO 8601 as TaskNotes writes it, for event links and timestamps. A formatter costs far more to make than to use, so
/// each kind is made once (writers once per time zone) and used one call at a time.
enum ISO8601 {
    private static let formatters = FormatterCache()

    static func parse(_ text: String) -> Date? {
        formatters.parse(text)
    }

    /// `2026-10-23T19:00:00+02:00`. At UTC+0 the offset is `+00:00`, as TaskNotes writes it, never `Z`.
    static func format(_ date: Date, timeZone: TimeZone) -> String {
        formatters.format(date, options: [.withInternetDateTime], timeZone: timeZone)
    }

    /// TaskNotes `date_modified` style: `2026-10-22T18:01:02.456+02:00`.
    static func formatWithMilliseconds(_ date: Date, timeZone: TimeZone) -> String {
        formatters.format(date, options: [.withInternetDateTime, .withFractionalSeconds], timeZone: timeZone)
    }
}

private final class FormatterCache: @unchecked Sendable {
    private let lock = NSLock()
    private let parsers: [ISO8601DateFormatter] = [ISO8601DateFormatter.Options]([
        [.withInternetDateTime], [.withInternetDateTime, .withFractionalSeconds],
    ]).map { options in
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        return formatter
    }
    private var writers: [String: ISO8601DateFormatter] = [:]

    func parse(_ text: String) -> Date? {
        lock.withLock { parsers.lazy.compactMap { $0.date(from: text) }.first }
    }

    func format(_ date: Date, options: ISO8601DateFormatter.Options, timeZone: TimeZone) -> String {
        lock.withLock {
            let key = "\(options.rawValue)|\(timeZone.identifier)"
            let formatter = writers[key] ?? {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = options
                formatter.timeZone = timeZone
                return formatter
            }()
            writers[key] = formatter
            let text = formatter.string(from: date)
            return text.hasSuffix("Z") ? text.dropLast() + "+00:00" : text
        }
    }
}
