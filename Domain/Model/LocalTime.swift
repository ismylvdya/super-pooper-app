import Foundation

/// A wall-clock time of day without a date ("16:00").
struct LocalTime: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let hour: Int
    let minute: Int

    static let midnight = LocalTime(hour: 0, minute: 0)!
    /// Half a day from either neighbouring date: a day kept as noon stays that day even read a few hours off.
    static let noon = LocalTime(hour: 12, minute: 0)!

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    /// Parses `HH:mm` (seconds, if present, are ignored).
    init?(string: String) {
        let parts = string.split(separator: ":")
        guard parts.count >= 2, parts[0].count == 2, parts[1].count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        self.init(hour: h, minute: m)
    }

    /// The wall-clock time of `date` in `calendar`.
    init(_ date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(minutesSinceMidnight: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }

    init(minutesSinceMidnight: Int) {
        let clamped = min(max(minutesSinceMidnight, 0), 24 * 60 - 1)
        self.hour = clamped / 60
        self.minute = clamped % 60
    }

    var minutesSinceMidnight: Int { hour * 60 + minute }
    var string: String { String(format: "%02d:%02d", hour, minute) }
    var description: String { string }

    static func < (lhs: LocalTime, rhs: LocalTime) -> Bool { lhs.minutesSinceMidnight < rhs.minutesSinceMidnight }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = LocalTime(string: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid time \(raw), expected HH:mm"))
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}
