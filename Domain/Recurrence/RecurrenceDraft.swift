import Foundation

/// What the recurrence editor edits: an Apple-Calendar-like choice that is written as a TaskNotes rule.
/// `raw` builds the rule text; `init(rule:)` reads an existing rule back. A rule with parts the editor has no control
/// for (several days of the month, several months, weekdays with a number outside a monthly rule) is not edited at
/// all (`canEdit`); parts it keeps without showing them — the start's and the end's time, the week start — are
/// written back as they were.
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
    /// The time of DTSTART, kept as the rule had it (it decides whether the UNTIL day itself still counts).
    var startTime: LocalTime?
    /// The time of UNTIL, kept as the rule had it.
    var untilTime: LocalTime?
    var weekStart: Weekday = .monday

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
        // Midnight is what a date-only DTSTART means too.
        startTime = rule.startTime == .midnight ? nil : rule.startTime
        untilTime = rule.untilTime
        weekStart = rule.weekStart
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

    /// Whether the editor shows all of `rule`, so that writing it back loses nothing. `start` is where its days start
    /// when it has no DTSTART.
    static func canEdit(_ rule: RecurrenceRule, start: LocalDate) -> Bool {
        let start = rule.startDate ?? start
        guard rule.count == nil || rule.untilDate == nil else { return false }
        switch rule.frequency {
        case .daily:
            return rule.byDay.isEmpty && rule.byMonthDay.isEmpty && rule.byMonth.isEmpty
        case .weekly:
            return rule.byDay.allSatisfy { $0.ordinal == nil } && rule.byMonthDay.isEmpty && rule.byMonth.isEmpty
        case .monthly:
            guard rule.byMonth.isEmpty else { return false }
            if rule.byDay.isEmpty {
                return rule.byMonthDay.count <= 1 && rule.byMonthDay.allSatisfy { $0 > 0 || $0 == -1 }
            }
            guard rule.byMonthDay.isEmpty, rule.byDay.count == 1, let ordinal = rule.byDay[0].ordinal else { return false }
            return MonthlyPattern.Ordinal(rawValue: ordinal) != nil
        case .yearly:
            // The editor writes the start's month and day.
            return rule.byDay.isEmpty && rule.byMonth.allSatisfy { $0 == start.month } && rule.byMonth.count <= 1
                && rule.byMonthDay.allSatisfy { $0 == start.day } && rule.byMonthDay.count <= 1
        }
    }

    var raw: String {
        var parts = ["DTSTART:\(Self.compact(start, startTime ?? .midnight))", "FREQ=\(frequency.rawValue)"]
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
        case .until(let day): parts.append("UNTIL=" + (untilTime.map { Self.compact(day, $0) } ?? Self.compact(day)))
        case .count(let count): parts.append("COUNT=\(count)")
        }
        if weekStart != .monday { parts.append("WKST=\(weekStart.icalCode)") }
        return parts.joined(separator: ";")
    }

    private static func compact(_ day: LocalDate) -> String {
        String(format: "%04d%02d%02d", day.year, day.month, day.day)
    }

    /// A date-time as TaskNotes writes it: wall-clock time with a `Z` that means nothing.
    private static func compact(_ day: LocalDate, _ time: LocalTime) -> String {
        compact(day) + String(format: "T%02d%02d00Z", time.hour, time.minute)
    }
}
