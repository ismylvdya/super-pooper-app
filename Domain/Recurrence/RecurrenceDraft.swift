import Foundation

/// What the recurrence editor edits: an Apple-Calendar-like choice that becomes a repeat rule.
/// `rule` builds it; `init(rule:)` reads an existing rule back. A rule with parts the editor has no control
/// for (several days of the month, several months, weekdays with a number outside a monthly rule) is not edited at
/// all (`canEdit`); parts it keeps without showing them — the start's time, the week start — are
/// written back as they were.
struct RecurrenceDraft: Equatable, Sendable {
    /// How a monthly rule picks its day.
    enum MonthlyDay: Hashable, Sendable {
        case dayOfMonth(Int)
        case lastDayOfMonth
        /// The nth weekday of the month; `-1` is the last one.
        case weekday(ordinal: Int, weekday: Weekday)
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
    /// The time of DTSTART, kept as the rule had it.
    var startTime: LocalTime?
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
    }

    /// Whether the editor shows all of `rule`, so that writing it back loses nothing. `start` is where its days start
    /// when it has no DTSTART.
    static func canEdit(_ rule: RecurrenceRule, start: LocalDate) -> Bool {
        let start = rule.startDate ?? start
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

    /// The rule the choice makes. The start always has a time (midnight when the rule had none).
    var rule: RecurrenceRule {
        var byDay: [RecurrenceWeekday] = []
        var byMonthDay: [Int] = []
        var byMonth: [Int] = []
        switch frequency {
        case .daily:
            break
        case .weekly:
            byDay = (weekdays.isEmpty ? [start.weekday] : weekdays.sorted()).map { RecurrenceWeekday(weekday: $0, ordinal: nil) }
        case .monthly:
            switch monthlyDay {
            case .dayOfMonth(let day): byMonthDay = [day]
            case .lastDayOfMonth: byMonthDay = [-1]
            case .weekday(let ordinal, let weekday): byDay = [RecurrenceWeekday(weekday: weekday, ordinal: ordinal)]
            }
        case .yearly:
            byMonth = [start.month]
            byMonthDay = [start.day]
        }
        return RecurrenceRule(startDate: start, startTime: startTime ?? .midnight, frequency: frequency, interval: interval,
                              byDay: byDay, byMonthDay: byMonthDay, byMonth: byMonth, count: nil, untilDate: nil,
                              untilTime: nil, weekStart: weekStart)
    }
}
