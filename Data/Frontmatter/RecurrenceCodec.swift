import Foundation

/// A repeat rule as TaskNotes writes it: `DTSTART:20261001T090000Z;FREQ=WEEKLY;INTERVAL=2;BYDAY=SA` — the start inline
/// in the rule, and wall-clock times with a `Z` that means nothing.
enum RecurrenceCodec {
    static func parse(_ text: String) -> Result<RecurrenceRule, RecurrenceParseError> {
        RecurrenceRuleParser(raw: text).parse()
    }

    /// The parts in the order the app always wrote them; a rule read and written back unchanged is not rewritten.
    static func format(_ rule: RecurrenceRule) -> String {
        var parts: [String] = []
        if let start = rule.startDate { parts.append("DTSTART:" + compact(start, rule.startTime)) }
        parts.append("FREQ=\(rule.frequency.rawValue)")
        if rule.interval > 1 { parts.append("INTERVAL=\(rule.interval)") }
        if !rule.byDay.isEmpty {
            parts.append("BYDAY=" + rule.byDay.map { (day) in (day.ordinal.map(String.init) ?? "") + code(day.weekday) }.joined(separator: ","))
        }
        if !rule.byMonth.isEmpty { parts.append("BYMONTH=" + rule.byMonth.map(String.init).joined(separator: ",")) }
        if !rule.byMonthDay.isEmpty { parts.append("BYMONTHDAY=" + rule.byMonthDay.map(String.init).joined(separator: ",")) }
        if let until = rule.untilDate { parts.append("UNTIL=" + compact(until, rule.untilTime)) }
        if let count = rule.count { parts.append("COUNT=\(count)") }
        if rule.weekStart != .monday { parts.append("WKST=\(code(rule.weekStart))") }
        return parts.joined(separator: ";")
    }

    /// `YYYYMMDD`.
    static func date(_ text: String) -> LocalDate? {
        guard text.count == 8, text.allSatisfy(\.isNumber),
              let year = Int(text.prefix(4)), let month = Int(text.dropFirst(4).prefix(2)), let day = Int(text.suffix(2))
        else { return nil }
        return LocalDate(year: year, month: month, day: day)
    }

    /// `MO` … `SU`, any letter case.
    static func weekday(_ text: String) -> Weekday? {
        Weekday.allCases.first { code($0) == text.uppercased() }
    }

    static func code(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: "MO"
        case .tuesday: "TU"
        case .wednesday: "WE"
        case .thursday: "TH"
        case .friday: "FR"
        case .saturday: "SA"
        case .sunday: "SU"
        }
    }

    private static func compact(_ day: LocalDate, _ time: LocalTime?) -> String {
        let date = String(format: "%04d%02d%02d", day.year, day.month, day.day)
        guard let time else { return date }
        return date + String(format: "T%02d%02d00Z", time.hour, time.minute)
    }
}
