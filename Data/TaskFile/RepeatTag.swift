import Foundation

/// A repeat rule in words, as a habit's line in the tasks file shows it after its marker: one word with hyphens, so a line
/// reads as `🔁 every-mon-sat`, `🔁 every-6-days`, `🔁 every-last-sat-of-month`. Only the app writes it; the rule itself
/// lives in the habit's JSON file.
enum RepeatTag {
    private static let ordinals = [1: "first", 2: "second", 3: "third", 4: "fourth", -1: "last"]

    static func text(of rule: RecurrenceRule) -> String {
        let interval = max(rule.interval, 1)
        let start = rule.startDate
        switch rule.frequency {
        case .daily:
            return interval == 1 ? "every-day" : "every-\(interval)-days"
        case .weekly:
            let week = interval == 1 ? "every" : "every-\(interval)-weeks"
            let days = rule.byDay.map(\.weekday).sorted().map(word)
            return ([week] + (days.isEmpty ? start.map { [word($0.weekday)] } ?? [] : days)).joined(separator: "-")
        case .monthly:
            let month = interval == 1 ? "of-month" : "of-every-\(interval)-months"
            if let entry = rule.byDay.first, let ordinal = entry.ordinal {
                return "every-\(ordinals[ordinal] ?? String(ordinal))-\(word(entry.weekday))-\(month)"
            }
            let day = rule.byMonthDay.first ?? start?.day ?? 1
            return day == -1 ? "every-last-day-\(month)" : "every-\(day)-\(month)"
        case .yearly:
            let every = interval == 1 ? "every-year" : "every-\(interval)-years"
            let month = rule.byMonth.first ?? start?.month ?? 1
            let day = rule.byMonthDay.first ?? start?.day ?? 1
            return every + String(format: "-%02d-%02d", month, day)
        }
    }

    private static func word(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: "mon"
        case .tuesday: "tue"
        case .wednesday: "wed"
        case .thursday: "thu"
        case .friday: "fri"
        case .saturday: "sat"
        case .sunday: "sun"
        }
    }
}
