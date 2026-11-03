import Foundation

/// Finds a date and a time in a typed name, as Reminders and Todoist do, by the words and formats of `DateGrammar`:
/// "in 5 min", "in 3 days", "today", "tomorrow", "mon", "next week", "6 Nov", "Nov 6", "6.11", "06.11.2026", "18:20",
/// "6:20", "at 6", "6pm". Any "H:MM" and "at H" is on the 24-hour clock; "am"/"pm" make it 12-hour. Days are logical
/// days (`DayContext`): before the day boundary "today" is still the day before. A date without a time has no time; a
/// time without a date is its nearest moment still to come. The first date and the first time in the text count;
/// impossible dates and times ("31.02", "25:10") are not dates.
struct DateDetector: Sendable {
    let grammar: DateGrammar
    private let patterns: [DatePattern]

    init(grammar: DateGrammar) {
        self.grammar = grammar
        patterns = DateDetector.patterns(for: grammar)
    }

    func detect(in text: String, context: DayContext) -> DetectedDate? {
        let found = patterns.flatMap { pattern in
            pattern.matches(in: text).compactMap { match in pattern.meaning(match, context).map { (match.range, $0) } }
        }
        .sorted { $0.0.location < $1.0.location }
        guard let first = found.first(where: { $0.1.isDayPart }) ?? found.first else { return nil }
        if case .moment(let due) = first.1 { return detected([first.0], due: due, in: text) }
        let partner = found.first { candidate in
            candidate.1.isDayPart != first.1.isDayPart && !candidate.1.isMoment && NSIntersectionRange(candidate.0, first.0).length == 0
        }
        let day = [first, partner].compactMap { $0 }.compactMap { $0.1.day }.first
        let time = [first, partner].compactMap { $0 }.compactMap { $0.1.time }.first
        let ranges = [first.0] + [partner?.0].compactMap { $0 }
        return detected(ranges, due: due(day: day, time: time, context: context), in: text)
    }

    /// `text` without the detected words: single spaces, trimmed.
    static func removing(_ detected: DetectedDate, from text: String) -> String {
        var rest = ""
        var cursor = text.startIndex
        for range in detected.ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) where range.lowerBound >= cursor {
            rest += text[cursor..<range.lowerBound] + " "
            cursor = range.upperBound
        }
        rest += text[cursor...]
        return rest.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func due(day: LocalDate?, time: LocalTime?, context: DayContext) -> TaskDue {
        if let day { return context.due(onLogicalDay: day, time: time) }
        guard let time else { return TaskDue(day: context.today) }
        let today = context.today
        let day = context.moment(time, onLogicalDay: today) > context.now ? today : today.adding(days: 1)
        return context.due(onLogicalDay: day, time: time)
    }

    /// The ranges in text order, those with only spaces between joined into one.
    private func detected(_ ranges: [NSRange], due: TaskDue, in text: String) -> DetectedDate? {
        var joined: [Range<String.Index>] = []
        for range in ranges.compactMap({ Range($0, in: text) }).sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = joined.last, text[last.upperBound..<range.lowerBound].allSatisfy(\.isWhitespace) {
                joined[joined.count - 1] = last.lowerBound..<range.upperBound
            } else {
                joined.append(range)
            }
        }
        return joined.isEmpty ? nil : DetectedDate(ranges: joined, due: due)
    }
}

private extension DatePattern.Meaning {
    var isDayPart: Bool {
        switch self {
        case .day, .moment: true
        case .time: false
        }
    }

    var isMoment: Bool {
        if case .moment = self { true } else { false }
    }

    var day: LocalDate? {
        if case .day(let day) = self { day } else { nil }
    }

    var time: LocalTime? {
        if case .time(let time) = self { time } else { nil }
    }
}
