import Foundation

/// The single date of a task (TaskNotes "scheduled", stored under `due`): a day, optionally with a time.
struct TaskDue: Hashable, Codable, Sendable {
    let day: LocalDate
    let time: LocalTime?

    init(day: LocalDate, time: LocalTime? = nil) {
        self.day = day
        self.time = time
    }

    /// Parses `YYYY-MM-DD` or `YYYY-MM-DDTHH:mm[:ss]` (local wall-clock time).
    init?(rawValue: String) {
        self.init(writtenWallClockOf: rawValue)
    }

    /// The date and the time of day of a timestamp as it is written, whatever offset follows
    /// (`2026-10-20T09:12:44.123+02:00` → 2026-10-20 09:12): the clock of the place it was written in.
    init?(writtenWallClockOf text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let day = LocalDate(isoString: trimmed) else { return nil }
        self.day = day
        if trimmed.count > 10 {
            let timePart = String(trimmed.dropFirst(11))
            guard let time = LocalTime(string: String(timePart.prefix(5))) else { return nil }
            self.time = time
        } else {
            self.time = nil
        }
    }

    var rawValue: String {
        guard let time else { return day.isoString }
        return "\(day.isoString)T\(time.string)"
    }

    func date(in calendar: Calendar) -> Date {
        day.startDate(in: calendar, offset: time ?? .midnight)
    }
}
