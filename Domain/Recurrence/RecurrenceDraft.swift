import Foundation

/// What the recurrence editor edits: an Apple-Calendar-like choice that is written as a TaskNotes rule.
/// `raw` builds the rule text; `init(rule:)` reads an existing rule back (unsupported shapes fall back to daily).
struct RecurrenceDraft: Equatable, Sendable {
    /// How a monthly rule picks its day.
    enum MonthlyDay: Hashable, Sendable {
        case dayOfMonth(Int)
        case lastDayOfMonth
        /// The nth weekday of the month; `-1` is the last one.
        case weekday(ordinal: Int, weekday: Weekday)
    }

    enum End: Hashable, Sendable {
        case never
        case until(LocalDate)
        case count(Int)
    }

    var start: LocalDate
    var frequency: RecurrenceFrequency = .daily
    var interval = 1
    /// Weekly days; empty means the weekday of `start`.
    var weekdays: Set<Weekday> = []
    var monthlyDay: MonthlyDay {
        didSet {
            // The last day and weekdays are only "On the"; a day number from the fifth on only "Each".
            switch monthlyDay {
            case .lastDayOfMonth, .weekday: monthlyMode = .onThe
            case .dayOfMonth: if MonthlyPattern(monthlyDay) == nil { monthlyMode = .each }
            }
        }
    }
    /// "Each" day number or "On the" first … last day or weekday; kept while editing, so day 1 picked as
    /// "Each 1" does not jump to "On the first day".
    var monthlyMode: MonthlyPattern.Mode
    var end: End = .never

    init(start: LocalDate) {
        self.start = start
        monthlyDay = .dayOfMonth(start.day)
        monthlyMode = .each
    }

    /// "On the" ordinal and kind of the monthly day (first day when it is a day number of "Each").
    var monthlyPattern: MonthlyPattern {
        get { MonthlyPattern(monthlyDay) ?? MonthlyPattern(ordinal: .first, kind: .day) }
        set { monthlyDay = newValue.monthlyDay }
    }

    /// Switching between "Each" (the start's day number) and "On the" (the first day).
    mutating func setMonthlyMode(_ mode: MonthlyPattern.Mode) {
        guard mode != monthlyMode else { return }
        monthlyMode = mode
        monthlyDay = mode == .each ? .dayOfMonth(start.day) : monthlyPattern.monthlyDay
    }

    init(rule: RecurrenceRule, fallbackStart: LocalDate) {
        self.init(start: rule.startDate ?? fallbackStart)
        frequency = rule.frequency
        interval = rule.interval
        weekdays = Set(rule.byDay.filter { $0.ordinal == nil }.map(\.weekday))
        if let day = rule.byMonthDay.first {
            monthlyDay = day == -1 ? .lastDayOfMonth : .dayOfMonth(max(day, 1))
        } else if let entry = rule.byDay.first(where: { $0.ordinal != nil }), let ordinal = entry.ordinal {
            monthlyDay = .weekday(ordinal: ordinal, weekday: entry.weekday)
        }
        monthlyMode = MonthlyPattern.mode(of: monthlyDay)
        if let count = rule.count {
            end = .count(count)
        } else if let until = rule.untilDate {
            end = .until(until)
        }
    }

    var raw: String {
        var parts = ["DTSTART:\(Self.compact(start))T000000Z", "FREQ=\(frequency.rawValue)"]
        if interval > 1 { parts.append("INTERVAL=\(interval)") }
        switch frequency {
        case .daily:
            break
        case .weekly:
            let days = weekdays.isEmpty ? [start.weekday] : weekdays.sorted()
            parts.append("BYDAY=" + days.map(\.icalCode).joined(separator: ","))
        case .monthly:
            switch monthlyDay {
            case .dayOfMonth(let day): parts.append("BYMONTHDAY=\(day)")
            case .lastDayOfMonth: parts.append("BYMONTHDAY=-1")
            case .weekday(let ordinal, let weekday): parts.append("BYDAY=\(ordinal)\(weekday.icalCode)")
            }
        case .yearly:
            parts += ["BYMONTH=\(start.month)", "BYMONTHDAY=\(start.day)"]
        }
        switch end {
        case .never: break
        case .until(let day): parts.append("UNTIL=\(Self.compact(day))")
        case .count(let count): parts.append("COUNT=\(count)")
        }
        return parts.joined(separator: ";")
    }

    private static func compact(_ day: LocalDate) -> String {
        String(format: "%04d%02d%02d", day.year, day.month, day.day)
    }
}
