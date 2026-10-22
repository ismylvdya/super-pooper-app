import Foundation

/// A recurrence rule in words ("Every 2 weeks on Sat at 09:00").
enum RecurrenceText {
    static func describe(_ task: TaskNote) -> String {
        guard let rule = task.recurrence else { return L10n.format("recurrence.unknown", task.recurrenceRaw ?? "") }
        var text = base(rule)
        if let time = task.due?.time { text += L10n.format("recurrence.at", time.string) }
        if let count = rule.count { text += L10n.format("recurrence.count", count) }
        if let until = rule.untilDate { text += L10n.format("recurrence.until", until.isoString) }
        return text
    }

    private static func base(_ rule: RecurrenceRule) -> String {
        let n = rule.interval
        switch rule.frequency {
        case .daily:
            return n == 1 ? L10n.string("recurrence.daily") : L10n.format("recurrence.everyDays", n)
        case .weekly:
            let days = rule.byDay.isEmpty ? "" : L10n.format("recurrence.on", weekdays(rule.byDay))
            return (n == 1 ? L10n.string("recurrence.weekly") : L10n.format("recurrence.everyWeeks", n)) + days
        case .monthly:
            let detail: String
            if !rule.byMonthDay.isEmpty {
                detail = L10n.format("recurrence.onDay", rule.byMonthDay.map(String.init).joined(separator: ", "))
            } else if !rule.byDay.isEmpty {
                detail = L10n.format("recurrence.on", weekdays(rule.byDay))
            } else {
                detail = ""
            }
            return (n == 1 ? L10n.string("recurrence.monthly") : L10n.format("recurrence.everyMonths", n)) + detail
        case .yearly:
            return n == 1 ? L10n.string("recurrence.yearly") : L10n.format("recurrence.everyYears", n)
        }
    }

    private static func weekdays(_ days: [RecurrenceWeekday]) -> String {
        let symbols = Calendar(identifier: .gregorian).shortWeekdaySymbols
        return days.map { day in
            let name = symbols[day.weekday.rawValue % 7]
            guard let ordinal = day.ordinal else { return name }
            return ordinal == -1 ? L10n.format("recurrence.last", name) : "\(ordinal). \(name)"
        }.joined(separator: ", ")
    }
}
