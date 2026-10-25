import Foundation

/// A recurrence rule in words ("Every 2 weeks on Sat at 09:00").
enum RecurrenceText {
    /// The rule the editor is building, in words.
    static func describe(_ draft: RecurrenceDraft, calendar: Calendar) -> String {
        guard case .success(let rule) = RecurrenceRule.parse(draft.raw) else { return "" }
        return describe(rule, calendar: calendar)
    }

    private static func describe(_ rule: RecurrenceRule, calendar: Calendar) -> String {
        var text = base(rule, calendar: calendar)
        if let count = rule.count { text += L10n.format("recurrence.count", count) }
        if let until = rule.untilDate { text += L10n.format("recurrence.until", until.isoString) }
        return text
    }

    private static func base(_ rule: RecurrenceRule, calendar: Calendar) -> String {
        let n = rule.interval
        switch rule.frequency {
        case .daily:
            return n == 1 ? L10n.string("recurrence.daily") : L10n.format("recurrence.everyDays", n)
        case .weekly:
            let days = rule.byDay.isEmpty ? "" : L10n.format("recurrence.on", weekdays(rule.byDay, calendar: calendar))
            return (n == 1 ? L10n.string("recurrence.weekly") : L10n.format("recurrence.everyWeeks", n)) + days
        case .monthly:
            let detail: String
            if !rule.byMonthDay.isEmpty {
                detail = L10n.format("recurrence.onDay", rule.byMonthDay.map(String.init).joined(separator: ", "))
            } else if !rule.byDay.isEmpty {
                detail = L10n.format("recurrence.on", weekdays(rule.byDay, calendar: calendar))
            } else {
                detail = ""
            }
            return (n == 1 ? L10n.string("recurrence.monthly") : L10n.format("recurrence.everyMonths", n)) + detail
        case .yearly:
            return n == 1 ? L10n.string("recurrence.yearly") : L10n.format("recurrence.everyYears", n)
        }
    }

    private static func weekdays(_ days: [RecurrenceWeekday], calendar: Calendar) -> String {
        days.map { day in
            let name = day.weekday.name(.short, in: calendar)
            guard let ordinal = day.ordinal else { return name }
            return ordinalWeekday(ordinal, name)
        }.joined(separator: L10n.string("common.listSeparator"))
    }

    /// "2. Mon", or "last Mon" for -1.
    static func ordinalWeekday(_ ordinal: Int, _ name: String) -> String {
        ordinal == -1 ? L10n.format("recurrence.last", name) : L10n.format("recurrence.nth", ordinal, name)
    }
}
