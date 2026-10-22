import Foundation

/// The repeating part of a rule with rrule.js defaults applied. Decides whether a day on or after the
/// anchor fits the FREQ/INTERVAL grid and the BY* filters; COUNT and UNTIL are left to the caller.
struct RecurrencePattern: Sendable {
    private struct NthWeekday: Sendable {
        let weekday: Weekday
        let ordinal: Int
    }

    private let frequency: RecurrenceFrequency
    private let interval: Int
    private let weekStart: Weekday
    private let anchor: LocalDate
    private let months: Set<Int>
    private let weekdays: Set<Weekday>
    private let nthWeekdays: [NthWeekday]
    /// Positive values count from the first day of the month, negative ones back from the last.
    private let monthDays: Set<Int>

    init(rule: RecurrenceRule, anchor: LocalDate) {
        frequency = rule.frequency
        interval = max(rule.interval, 1)
        weekStart = rule.weekStart
        self.anchor = anchor

        var months = rule.byMonth
        var monthDays = rule.byMonthDay
        var byDay = rule.byDay
        // Like rrule.js: without BYDAY and BYMONTHDAY the anchor supplies the day filter.
        if byDay.isEmpty && monthDays.isEmpty {
            switch rule.frequency {
            case .daily:
                break
            case .weekly:
                byDay = [RecurrenceWeekday(weekday: anchor.weekday, ordinal: nil)]
            case .monthly:
                monthDays = [anchor.day]
            case .yearly:
                if months.isEmpty { months = [anchor.month] }
                monthDays = [anchor.day]
            }
        }

        // Ordinals only mean something within a month or a year; DAILY and WEEKLY ignore them.
        let usesOrdinals = rule.frequency == .monthly || rule.frequency == .yearly
        self.months = Set(months)
        self.monthDays = Set(monthDays)
        weekdays = Set(byDay.filter { !usesOrdinals || $0.ordinal == nil }.map(\.weekday))
        nthWeekdays = usesOrdinals
            ? byDay.compactMap { entry in entry.ordinal.map { NthWeekday(weekday: entry.weekday, ordinal: $0) } }
            : []
    }

    func matches(_ day: LocalDate) -> Bool {
        day >= anchor && isInActivePeriod(day) && passesFilters(day)
    }

    /// The first matching day in `start...end`, skipping inactive periods and filtered-out months.
    func firstMatch(onOrAfter start: LocalDate, through end: LocalDate) -> LocalDate? {
        var candidate = max(start, anchor)
        while candidate <= end {
            if !isInActivePeriod(candidate) {
                candidate = startOfNextActivePeriod(after: candidate)
            } else if !months.isEmpty && !months.contains(candidate.month) {
                candidate = Self.firstDayOfNextMonth(after: candidate)
            } else if passesFilters(candidate) {
                return candidate
            } else {
                candidate = candidate.adding(days: 1)
            }
        }
        return nil
    }

    // MARK: - Periods

    /// Periods are counted from the anchor's day, WKST-aligned week, month or year.
    private func periodIndex(of day: LocalDate) -> Int {
        switch frequency {
        case .daily: anchor.days(until: day)
        case .weekly: (weekStartDayNumber(of: day) - weekStartDayNumber(of: anchor)) / 7
        case .monthly: Self.monthNumber(of: day) - Self.monthNumber(of: anchor)
        case .yearly: day.year - anchor.year
        }
    }

    private func isInActivePeriod(_ day: LocalDate) -> Bool {
        periodIndex(of: day) % interval == 0
    }

    private func startOfNextActivePeriod(after day: LocalDate) -> LocalDate {
        let index = (periodIndex(of: day) / interval + 1) * interval
        switch frequency {
        case .daily: return anchor.adding(days: index)
        case .weekly: return LocalDate(dayNumber: weekStartDayNumber(of: anchor) + index * 7)
        case .monthly: return Self.firstDay(ofMonthNumber: Self.monthNumber(of: anchor) + index)
        case .yearly: return Self.firstDay(ofMonthNumber: (anchor.year + index) * 12)
        }
    }

    private func weekStartDayNumber(of day: LocalDate) -> Int {
        day.dayNumber - (day.weekday.rawValue - weekStart.rawValue + 7) % 7
    }

    // MARK: - Filters

    private func passesFilters(_ day: LocalDate) -> Bool {
        let weekday = day.weekday
        return (months.isEmpty || months.contains(day.month))
            && (weekdays.isEmpty || weekdays.contains(weekday))
            && (nthWeekdays.isEmpty || nthWeekdays.contains { isNth($0, day: day, weekday: weekday) })
            && (monthDays.isEmpty || passesMonthDays(day))
    }

    private func passesMonthDays(_ day: LocalDate) -> Bool {
        let daysInMonth = LocalDate.daysInMonth(year: day.year, month: day.month)
        return monthDays.contains(day.day) || monthDays.contains(day.day - daysInMonth - 1)
    }

    private func isNth(_ nth: NthWeekday, day: LocalDate, weekday: Weekday) -> Bool {
        guard nth.weekday == weekday else { return false }
        let span = ordinalSpan(of: day)
        let ordinal = nth.ordinal > 0 ? span.offset / 7 + 1 : -((span.length - 1 - span.offset) / 7 + 1)
        return ordinal == nth.ordinal
    }

    /// Ordinals count within the month, except YEARLY without BYMONTH, where they count within the year.
    private func ordinalSpan(of day: LocalDate) -> (offset: Int, length: Int) {
        guard frequency == .yearly && months.isEmpty else {
            return (day.day - 1, LocalDate.daysInMonth(year: day.year, month: day.month))
        }
        let yearStart = Self.firstDay(ofMonthNumber: day.year * 12)
        return (yearStart.days(until: day), LocalDate.isLeapYear(day.year) ? 366 : 365)
    }

    // MARK: - Calendar helpers

    /// Months since January of year 0.
    private static func monthNumber(of day: LocalDate) -> Int {
        day.year * 12 + day.month - 1
    }

    private static func firstDay(ofMonthNumber number: Int) -> LocalDate {
        let year = number >= 0 ? number / 12 : -((11 - number) / 12)
        guard let date = LocalDate(year: year, month: number - year * 12 + 1, day: 1) else {
            preconditionFailure("Month number \(number) maps to an invalid month")
        }
        return date
    }

    private static func firstDayOfNextMonth(after day: LocalDate) -> LocalDate {
        day.adding(days: LocalDate.daysInMonth(year: day.year, month: day.month) - day.day + 1)
    }
}
