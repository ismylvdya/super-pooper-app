import Foundation

/// A calendar day without time or time zone ("2026-10-23").
/// TaskNotes stores days as floating local dates, so the domain works with them directly.
struct LocalDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), day >= 1, day <= LocalDate.daysInMonth(year: year, month: month) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `YYYY-MM-DD`. A trailing time part (`YYYY-MM-DDTHH:mm…`) is ignored.
    init?(isoString: String) {
        let trimmed = isoString.trimmingCharacters(in: .whitespaces)
        let datePart = trimmed.prefix(10)
        let parts = datePart.split(separator: "-", omittingEmptySubsequences: false)
        guard datePart.count == 10, parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        if trimmed.count > 10 {
            let next = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 10)]
            guard next == "T" || next == " " else { return nil }
        }
        self.init(year: y, month: m, day: d)
    }

    /// Parses the compact iCalendar form `YYYYMMDD`.
    init?(compactString: String) {
        guard compactString.count == 8, compactString.allSatisfy(\.isNumber),
              let y = Int(compactString.prefix(4)),
              let m = Int(compactString.dropFirst(4).prefix(2)),
              let d = Int(compactString.suffix(2)) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    /// The day of `date` as seen in `calendar` (whose time zone decides the boundary).
    init(_ date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = parts.year ?? 1970
        self.month = parts.month ?? 1
        self.day = parts.day ?? 1
    }

    var isoString: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var description: String { isoString }

    /// Days since 1970-01-01 (proleptic Gregorian), used for arithmetic.
    var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let monthIndex = (month + 9) % 12
        let dayOfYear = (153 * monthIndex + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    init(dayNumber: Int) {
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let d = dayOfYear - (153 * monthIndex + 2) / 5 + 1
        let m = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        self.year = yearOfEra + era * 400 + (m <= 2 ? 1 : 0)
        self.month = m
        self.day = d
    }

    func adding(days: Int) -> LocalDate { LocalDate(dayNumber: dayNumber + days) }

    func days(until other: LocalDate) -> Int { other.dayNumber - dayNumber }

    var weekday: Weekday {
        // 1970-01-01 was a Thursday.
        let index = ((dayNumber % 7) + 7 + 3) % 7
        return Weekday.allCases[index]
    }

    /// Start of this day in `calendar`, shifted by `offset` (e.g. a 04:00 day boundary).
    func startDate(in calendar: Calendar, offset: LocalTime = .midnight) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: offset.hour, minute: offset.minute)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = LocalDate(isoString: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date \(raw)"))
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
}

/// ISO weekday, Monday first (matches iCalendar `MO`…`SU`).
enum Weekday: Int, CaseIterable, Codable, Sendable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    init?(icalCode: String) {
        guard let match = Weekday.allCases.first(where: { $0.icalCode == icalCode.uppercased() }) else { return nil }
        self = match
    }

    var icalCode: String {
        switch self {
        case .monday: "MO"
        case .tuesday: "TU"
        case .wednesday: "WE"
        case .thursday: "TH"
        case .friday: "FR"
        case .saturday: "SA"
        case .sunday: "SU"
        }
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A wall-clock time of day without a date ("16:00").
struct LocalTime: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let hour: Int
    let minute: Int

    static let midnight = LocalTime(hour: 0, minute: 0)!

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    /// Parses `HH:mm` (seconds, if present, are ignored).
    init?(string: String) {
        let parts = string.split(separator: ":")
        guard parts.count >= 2, parts[0].count == 2, parts[1].count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        self.init(hour: h, minute: m)
    }

    init(minutesSinceMidnight: Int) {
        let clamped = min(max(minutesSinceMidnight, 0), 24 * 60 - 1)
        self.hour = clamped / 60
        self.minute = clamped % 60
    }

    var minutesSinceMidnight: Int { hour * 60 + minute }
    var string: String { String(format: "%02d:%02d", hour, minute) }
    var description: String { string }

    static func < (lhs: LocalTime, rhs: LocalTime) -> Bool { lhs.minutesSinceMidnight < rhs.minutesSinceMidnight }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = LocalTime(string: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid time \(raw), expected HH:mm"))
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}
