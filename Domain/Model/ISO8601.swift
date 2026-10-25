import Foundation

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
