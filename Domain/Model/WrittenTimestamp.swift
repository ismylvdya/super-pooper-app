import Foundation

/// A date, optionally with a time of day, as notes write it: `YYYY-MM-DD` or `YYYY-MM-DDTHH:mm` (a space instead of `T`
/// too), with optional seconds and fraction, and optionally an offset (`Z`, `+02:00`, `-0500`, `+03`) that makes it a
/// moment rather than a time on the clock. TaskNotes writes `due` without an offset and timestamps with one.
struct WrittenTimestamp: Sendable {
    let day: LocalDate
    let time: LocalTime?
    let seconds: Int
    /// Seconds east of UTC; nil for a wall-clock value.
    let offset: Int?

    init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let day = LocalDate(isoString: trimmed) else { return nil }
        self.day = day
        guard trimmed.count > 10 else {
            time = nil
            seconds = 0
            offset = nil
            return
        }
        var rest = Substring(trimmed.dropFirst(11))
        guard let time = LocalTime(string: String(rest.prefix(5))), rest.count >= 5 else { return nil }
        self.time = time
        rest = rest.dropFirst(5)
        var seconds = 0
        if rest.first == ":" {
            guard let value = Int(rest.dropFirst().prefix(2)), rest.count >= 3, value < 60 else { return nil }
            seconds = value
            rest = rest.dropFirst(3)
            if rest.first == "." {
                rest = rest.dropFirst().drop(while: \.isNumber)
            }
        }
        self.seconds = seconds
        guard let zone = Zone(rest) else { return nil }
        offset = zone.offset
    }

    /// The moment it stands for, when an offset is written.
    var moment: Date? {
        guard let offset, let zone = TimeZone(secondsFromGMT: offset) else { return nil }
        var parts = DateComponents(year: day.year, month: day.month, day: day.day,
                                   hour: time?.hour ?? 0, minute: time?.minute ?? 0, second: seconds)
        parts.timeZone = zone
        return Calendar(identifier: .gregorian).date(from: parts)
    }

    /// What follows the time: nothing (a wall-clock value), `Z`, or `±HH[[:]mm]`; anything else is not a timestamp.
    private struct Zone {
        let offset: Int?

        init?(_ text: Substring) {
            if text.isEmpty {
                offset = nil
                return
            }
            if text == "Z" || text == "z" {
                offset = 0
                return
            }
            guard let sign = text.first, sign == "+" || sign == "-",
                  text.dropFirst().allSatisfy({ $0.isNumber || $0 == ":" }) else { return nil }
            let digits = String(text.dropFirst().filter(\.isNumber))
            guard digits.count == 2 || digits.count == 4, let hours = Int(digits.prefix(2)),
                  let minutes = Int(digits.count == 4 ? String(digits.suffix(2)) : "0"), hours <= 14, minutes < 60 else { return nil }
            offset = (sign == "-" ? -1 : 1) * (hours * 3600 + minutes * 60)
        }
    }
}
