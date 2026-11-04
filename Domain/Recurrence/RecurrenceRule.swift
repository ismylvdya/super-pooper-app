import Foundation

enum RecurrenceFrequency: String, Codable, Sendable {
    case daily = "DAILY", weekly = "WEEKLY", monthly = "MONTHLY", yearly = "YEARLY"
}

/// A `BYDAY` entry: `MO`, or with an ordinal such as `2MO` (second Monday) or `-1FR` (last Friday).
struct RecurrenceWeekday: Hashable, Codable, Sendable {
    let weekday: Weekday
    let ordinal: Int?
}

/// How an item repeats, in the terms of an iCalendar repeat rule (frequency, interval, days, end). The start and the end
/// are wall-clock values. How a store writes it down is the store's business.
struct RecurrenceRule: Hashable, Codable, Sendable {
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
}

extension RecurrenceRule {
    /// A repeat goes on forever: an end an older rule has (a date, a number of times) is not kept.
    var withoutEnd: RecurrenceRule {
        RecurrenceRule(startDate: startDate, startTime: startTime, frequency: frequency, interval: interval, byDay: byDay, byMonthDay: byMonthDay,
                       byMonth: byMonth, count: nil, untilDate: nil, untilTime: nil, weekStart: weekStart)
    }

    /// The rule counted from `day`, when one is known.
    func starting(_ day: LocalDate?) -> RecurrenceRule {
        RecurrenceRule(startDate: day ?? startDate, startTime: startTime, frequency: frequency, interval: interval, byDay: byDay, byMonthDay: byMonthDay,
                       byMonth: byMonth, count: count, untilDate: untilDate, untilTime: untilTime, weekStart: weekStart)
    }
}
