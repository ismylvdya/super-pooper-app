import Foundation

/// Parses a TaskNotes recurrence: an optional `DTSTART:` part and `KEY=VALUE` rule parts separated by
/// `;` or line breaks. Keys are case-insensitive and rule parts may carry an `RRULE:` prefix.
struct RecurrenceRuleParser {
    let raw: String

    func parse() -> Result<RecurrenceRule, RecurrenceParseError> {
        let parts = raw
            .split(whereSeparator: { $0 == ";" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return .failure(.empty) }

        var draft = RuleDraft()
        for part in parts {
            if let error = draft.apply(part) { return .failure(error) }
        }
        return draft.build(raw: raw)
    }
}

private enum RulePartKey: String {
    case start = "DTSTART"
    case frequency = "FREQ"
    case interval = "INTERVAL"
    case byDay = "BYDAY"
    case byMonthDay = "BYMONTHDAY"
    case byMonth = "BYMONTH"
    case count = "COUNT"
    case until = "UNTIL"
    case weekStart = "WKST"
}

private struct RuleDraft {
    private static let maxInterval = 10_000
    private static let unsupportedFrequencies: Set<String> = ["HOURLY", "MINUTELY", "SECONDLY"]

    private var start: RuleValue.DateTime?
    private var frequency: RecurrenceFrequency?
    private var interval: Int?
    private var byDay: [RecurrenceWeekday] = []
    private var byMonthDay: [Int] = []
    private var byMonth: [Int] = []
    private var count: Int?
    private var until: RuleValue.DateTime?
    private var weekStart: Weekday?
    private var seenKeys: Set<RulePartKey> = []

    mutating func apply(_ part: String) -> RecurrenceParseError? {
        if part.prefix(8).uppercased() == "DTSTART:" {
            return apply(.start, value: String(part.dropFirst(8)))
        }
        let body = part.prefix(6).uppercased() == "RRULE:" ? String(part.dropFirst(6)) : part
        guard let separator = body.firstIndex(of: "="), !body[..<separator].contains(":") else {
            return .unsupportedPart(Self.propertyName(of: body))
        }
        let keyText = body[..<separator].trimmingCharacters(in: .whitespaces).uppercased()
        let value = body[body.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        // DTSTART is only accepted in its `DTSTART:` property form.
        guard let key = RulePartKey(rawValue: keyText), key != .start else { return .unsupportedPart(keyText) }
        return apply(key, value: value)
    }

    func build(raw: String) -> Result<RecurrenceRule, RecurrenceParseError> {
        guard let frequency else { return .failure(.missingFrequency) }
        return .success(RecurrenceRule(
            raw: raw,
            startDate: start?.date,
            startTime: start?.time,
            frequency: frequency,
            interval: interval ?? 1,
            byDay: byDay,
            byMonthDay: byMonthDay,
            byMonth: byMonth,
            count: count,
            untilDate: until?.date,
            untilTime: until?.time,
            weekStart: weekStart ?? .monday
        ))
    }

    private mutating func apply(_ key: RulePartKey, value: String) -> RecurrenceParseError? {
        let invalid = RecurrenceParseError.invalidValue(part: key.rawValue, value: value)
        guard seenKeys.insert(key).inserted else { return invalid }

        switch key {
        case .start:
            guard let parsed = RuleValue.dateTime(value) else { return invalid }
            start = parsed
        case .frequency:
            let upper = value.uppercased()
            if Self.unsupportedFrequencies.contains(upper) { return .unsupportedPart("FREQ=\(upper)") }
            guard let parsed = RecurrenceFrequency(rawValue: upper) else { return invalid }
            frequency = parsed
        case .interval:
            guard let parsed = RuleValue.integer(value, in: 1...Self.maxInterval) else { return invalid }
            interval = parsed
        case .count:
            guard let parsed = RuleValue.integer(value, in: 1...Int.max) else { return invalid }
            count = parsed
        case .byDay:
            guard let parsed = RuleValue.list(value, RuleValue.recurrenceWeekday) else { return invalid }
            byDay = parsed
        case .byMonthDay:
            guard let parsed = RuleValue.list(value, RuleValue.monthDay) else { return invalid }
            byMonthDay = parsed
        case .byMonth:
            guard let parsed = RuleValue.list(value, { RuleValue.integer($0, in: 1...12) }) else { return invalid }
            byMonth = parsed
        case .until:
            guard let parsed = RuleValue.dateTime(value) else { return invalid }
            until = parsed
        case .weekStart:
            guard let parsed = Weekday(icalCode: value) else { return invalid }
            weekStart = parsed
        }
        return nil
    }

    /// `EXDATE:20261005` → `EXDATE`; a part without a property name is reported whole.
    private static func propertyName(of part: String) -> String {
        guard let colon = part.firstIndex(of: ":") else { return part }
        return part[..<colon].uppercased()
    }
}

private enum RuleValue {
    typealias DateTime = (date: LocalDate, time: LocalTime?)

    private static let maxOrdinal = 53

    static func list<Element>(_ value: String, _ element: (String) -> Element?) -> [Element]? {
        let items = value.split(separator: ",", omittingEmptySubsequences: false)
        let parsed = items.compactMap { element($0.trimmingCharacters(in: .whitespaces)) }
        return parsed.count == items.count ? parsed : nil
    }

    static func integer(_ text: String, in range: ClosedRange<Int>) -> Int? {
        guard let value = Int(text), range.contains(value) else { return nil }
        return value
    }

    /// `1`…`31`, or `-1`…`-31` counting from the end of the month.
    static func monthDay(_ text: String) -> Int? {
        guard let value = integer(text, in: -31...31), value != 0 else { return nil }
        return value
    }

    /// `MO`, `2MO`, `+2MO` or `-1FR`.
    static func recurrenceWeekday(_ text: String) -> RecurrenceWeekday? {
        guard text.count >= 2, let weekday = Weekday(icalCode: String(text.suffix(2))) else { return nil }
        let ordinalText = String(text.dropLast(2))
        if ordinalText.isEmpty { return RecurrenceWeekday(weekday: weekday, ordinal: nil) }
        guard let ordinal = integer(ordinalText, in: -maxOrdinal...maxOrdinal), ordinal != 0 else { return nil }
        return RecurrenceWeekday(weekday: weekday, ordinal: ordinal)
    }

    /// `YYYYMMDD` or `YYYYMMDDTHHMMSS[Z]`. Seconds are dropped and `Z` is ignored: values are floating.
    static func dateTime(_ text: String) -> DateTime? {
        let value = text.uppercased()
        guard let date = LocalDate(compactString: String(value.prefix(8))) else { return nil }
        let rest = value.dropFirst(8)
        if rest.isEmpty { return (date, nil) }

        var clock = rest.dropFirst()
        if clock.last == "Z" { clock = clock.dropLast() }
        guard rest.first == "T", clock.count == 6, clock.allSatisfy({ $0.isASCII && $0.isNumber }),
              let hour = Int(clock.prefix(2)), let minute = Int(clock.dropFirst(2).prefix(2)),
              let second = Int(clock.suffix(2)), second < 60,
              let time = LocalTime(hour: hour, minute: minute) else { return nil }
        return (date, time)
    }
}
