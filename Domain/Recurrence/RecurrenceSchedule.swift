import Foundation

/// Which days a recurring task has an instance on, matching TaskNotes (rrule.js with floating dates).
/// Build it once per rule and reuse it: rules with COUNT enumerate their occurrences up front.
struct RecurrenceSchedule: Sendable {
    /// How far ahead `nextOccurrence(onOrAfter:)` and COUNT enumeration look.
    private static let searchHorizonDays = 100 * 366

    let rule: RecurrenceRule
    let anchor: LocalDate
    private let pattern: RecurrencePattern
    private let lastDay: LocalDate?
    /// Ascending occurrences of a COUNT rule; `nil` when the rule has no COUNT.
    private let countedOccurrences: [LocalDate]?

    init(rule: RecurrenceRule, fallbackStart: LocalDate) {
        let anchor = rule.startDate ?? fallbackStart
        let pattern = RecurrencePattern(rule: rule, anchor: anchor)
        let lastDay = Self.lastDay(of: rule)
        self.rule = rule
        self.anchor = anchor
        self.pattern = pattern
        self.lastDay = lastDay
        countedOccurrences = rule.count.map { count in
            Self.firstOccurrences(count, of: pattern, from: anchor, through: lastDay)
        }
    }

    func occurs(on day: LocalDate) -> Bool {
        guard let counted = countedOccurrences else {
            return isNotPastUntil(day) && pattern.matches(day)
        }
        let index = Self.firstIndex(onOrAfter: day, in: counted)
        return index < counted.count && counted[index] == day
    }

    func occurrences(from start: LocalDate, through end: LocalDate) -> [LocalDate] {
        if let counted = countedOccurrences {
            return Array(counted[Self.firstIndex(onOrAfter: start, in: counted)...].prefix { $0 <= end })
        }
        let last = lastDay.map { min($0, end) } ?? end
        var result: [LocalDate] = []
        var cursor = start
        while let next = pattern.firstMatch(onOrAfter: cursor, through: last) {
            result.append(next)
            cursor = next.adding(days: 1)
        }
        return result
    }

    func nextOccurrence(onOrAfter day: LocalDate) -> LocalDate? {
        if let counted = countedOccurrences {
            let index = Self.firstIndex(onOrAfter: day, in: counted)
            return index < counted.count ? counted[index] : nil
        }
        let start = max(day, anchor)
        let horizon = start.adding(days: Self.searchHorizonDays)
        return pattern.firstMatch(onOrAfter: start, through: lastDay.map { min($0, horizon) } ?? horizon)
    }

    private func isNotPastUntil(_ day: LocalDate) -> Bool {
        guard let lastDay else { return true }
        return day <= lastDay
    }

    /// rrule.js compares each occurrence's date-time (day + DTSTART time) with UNTIL, and a date-only
    /// UNTIL means midnight. So a timed DTSTART has no instance on a date-only UNTIL day.
    private static func lastDay(of rule: RecurrenceRule) -> LocalDate? {
        guard let untilDate = rule.untilDate else { return nil }
        let occurrenceTime = rule.startTime ?? .midnight
        let untilTime = rule.untilTime ?? .midnight
        return occurrenceTime <= untilTime ? untilDate : untilDate.adding(days: -1)
    }

    /// COUNT counts matching days from the anchor; the anchor itself only counts if it matches.
    private static func firstOccurrences(
        _ count: Int,
        of pattern: RecurrencePattern,
        from anchor: LocalDate,
        through lastDay: LocalDate?
    ) -> [LocalDate] {
        let horizon = anchor.adding(days: searchHorizonDays)
        let end = lastDay.map { min($0, horizon) } ?? horizon
        var result: [LocalDate] = []
        var cursor = anchor
        while result.count < count, let next = pattern.firstMatch(onOrAfter: cursor, through: end) {
            result.append(next)
            cursor = next.adding(days: 1)
        }
        return result
    }

    private static func firstIndex(onOrAfter day: LocalDate, in days: [LocalDate]) -> Int {
        var low = 0
        var high = days.count
        while low < high {
            let middle = (low + high) / 2
            if days[middle] < day {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }
}
