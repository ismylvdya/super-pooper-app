import Foundation

enum RecurrenceFrequency: String, Codable, Sendable {
    case daily = "DAILY", weekly = "WEEKLY", monthly = "MONTHLY", yearly = "YEARLY"
}

/// A `BYDAY` entry: `MO`, or with an ordinal such as `2MO` (second Monday) or `-1FR` (last Friday).
struct RecurrenceWeekday: Hashable, Codable, Sendable {
    let weekday: Weekday
    let ordinal: Int?
}

enum RecurrenceParseError: Error, Equatable, Sendable {
    case empty
    case missingFrequency
    case unsupportedPart(String)
    case invalidValue(part: String, value: String)
}

/// A recurrence in the TaskNotes format, e.g. `DTSTART:20261001T090000Z;FREQ=WEEKLY;INTERVAL=2;BYDAY=SA`.
/// DTSTART and UNTIL are floating wall-clock values: TaskNotes writes local time with a misleading `Z`.
struct RecurrenceRule: Hashable, Codable, Sendable {
    let raw: String
    let startDate: LocalDate?
    let startTime: LocalTime?
    let frequency: RecurrenceFrequency
    let interval: Int
    let byDay: [RecurrenceWeekday]
    let byMonthDay: [Int]
    let byMonth: [Int]
    let count: Int?
    let untilDate: LocalDate?
    let untilTime: LocalTime?
    let weekStart: Weekday

    static func parse(_ raw: String) -> Result<RecurrenceRule, RecurrenceParseError> {
        RecurrenceRuleParser(raw: raw).parse()
    }
}

/// Encoded as the raw string and re-parsed on decoding, so a decoded rule is always valid.
extension RecurrenceRule {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch RecurrenceRule.parse(raw) {
        case .success(let rule):
            self = rule
        case .failure(let error):
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid recurrence \(raw): \(error)"
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}
