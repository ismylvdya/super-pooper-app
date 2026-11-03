import Foundation

/// The patterns of `DateDetector`, built from the grammar's words.
extension DateDetector {
    static func patterns(for grammar: DateGrammar) -> [DatePattern] {
        let words = DatePattern.alternatives
        let months = grammar.months.flatMap { month, names in names.map { ($0.lowercased(), month) } }
        let monthOf = Dictionary(months, uniquingKeysWith: { first, _ in first })
        let weekdayOf = Dictionary(grammar.weekdays.flatMap { day, names in names.map { ($0.lowercased(), day) } },
                                   uniquingKeysWith: { first, _ in first })
        let unitOf = Dictionary(grammar.units.flatMap { unit, names in names.map { ($0.lowercased(), unit) } },
                                uniquingKeysWith: { first, _ in first })
        let monthWords = words(Array(monthOf.keys))
        let dateSeparator = words(grammar.dateSeparators)
        let timeSeparator = NSRegularExpression.escapedPattern(for: grammar.timeSeparator)
        let half = #"(?:\s*(?<half>"# + words(grammar.am + grammar.pm) + "))?"
        let pm = Set(grammar.pm.map { $0.lowercased() })

        func hour(_ match: DatePattern.Match, minute: Int = 0) -> LocalTime? {
            guard let hour = match.groups["hour"].flatMap(Int.init) else { return nil }
            guard let half = match.groups["half"] else { return LocalTime(hour: hour, minute: minute) }
            guard (1...12).contains(hour) else { return nil }
            return LocalTime(hour: hour % 12 + (pm.contains(half) ? 12 : 0), minute: minute)
        }

        return [
            DatePattern(words(grammar.relativePrefix) + #"\s+(?<count>\d{1,4})\s*(?<unit>"# + words(Array(unitOf.keys)) + ")",
                        groups: ["count", "unit"]) { match, context in
                guard let count = match.groups["count"].flatMap(Int.init), let unit = match.groups["unit"].flatMap({ unitOf[$0] })
                else { return nil }
                switch unit {
                case .day: return .day(context.today.adding(days: count))
                case .minute, .hour:
                    let moment = context.now.addingTimeInterval(TimeInterval(count * (unit == .hour ? 3600 : 60)))
                    return .moment(TaskDue(day: LocalDate(moment, in: context.calendar), time: LocalTime(moment, in: context.calendar)))
                }
            },
            DatePattern(words(grammar.today), groups: []) { _, context in .day(context.today) },
            DatePattern(words(grammar.tomorrow), groups: []) { _, context in .day(context.today.adding(days: 1)) },
            DatePattern(words(grammar.nextWeek), groups: []) { _, context in .day(context.today.weekStart.adding(days: 7)) },
            DatePattern("(?<weekday>" + words(Array(weekdayOf.keys)) + ")", groups: ["weekday"]) { match, context in
                guard let weekday = match.groups["weekday"].flatMap({ weekdayOf[$0] }) else { return nil }
                let ahead = (weekday.rawValue - context.today.weekday.rawValue + 6) % 7 + 1
                return .day(context.today.adding(days: ahead))
            },
            DatePattern(#"(?<day>\d{1,2})\s+(?<month>"# + monthWords + #")(?:\s+(?<year>\d{4}))?"#,
                        groups: ["day", "month", "year"]) { match, context in
                day(match, month: match.groups["month"].flatMap { monthOf[$0] }, context: context)
            },
            DatePattern("(?<month>" + monthWords + #")\s+(?<day>\d{1,2})(?:,?\s+(?<year>\d{4}))?"#,
                        groups: ["day", "month", "year"]) { match, context in
                day(match, month: match.groups["month"].flatMap { monthOf[$0] }, context: context)
            },
            DatePattern(#"(?<day>\d{1,2})"# + dateSeparator + #"(?<month>\d{1,2})(?:"# + dateSeparator + #"(?<year>\d{4}))?"#,
                        groups: ["day", "month", "year"]) { match, context in
                day(match, month: match.groups["month"].flatMap(Int.init), context: context)
            },
            DatePattern(#"(?<hour>\d{1,2})"# + timeSeparator + #"(?<minute>\d{2})"# + half,
                        groups: ["hour", "minute", "half"]) { match, _ in
                guard let minute = match.groups["minute"].flatMap(Int.init) else { return nil }
                return hour(match, minute: minute).map { .time($0) }
            },
            DatePattern(words(grammar.at) + #"\s+(?<hour>\d{1,2})(?:"# + timeSeparator + #"(?<minute>\d{2}))?"# + half,
                        groups: ["hour", "minute", "half"]) { match, _ in
                let minute = match.groups["minute"].flatMap(Int.init) ?? 0
                return hour(match, minute: minute).map { .time($0) }
            },
            DatePattern(#"(?<hour>\d{1,2})\s*(?<half>"# + words(grammar.am + grammar.pm) + ")", groups: ["hour", "half"]) { match, _ in
                hour(match).map { .time($0) }
            },
        ]
    }

    /// The day of a written day and month: with a year as written, without one the next such day from today on.
    private static func day(_ match: DatePattern.Match, month: Int?, context: DayContext) -> DatePattern.Meaning? {
        guard let month, let day = match.groups["day"].flatMap(Int.init) else { return nil }
        if let year = match.groups["year"].flatMap(Int.init) {
            return LocalDate(year: year, month: month, day: day).map { .day($0) }
        }
        let today = context.today
        let next = (0...yearsToFindADay).lazy
            .compactMap { LocalDate(year: today.year + $0, month: month, day: day) }
            .first { $0 >= today }
        return next.map { .day($0) }
    }

    /// 29 February comes back within this many years.
    private static var yearsToFindADay: Int { 8 }
}
