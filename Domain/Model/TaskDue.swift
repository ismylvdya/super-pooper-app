import Foundation

/// The single date of a task (TaskNotes "scheduled", stored under `due`): a day, optionally with a time.
struct TaskDue: Hashable, Codable, Sendable {
    let day: LocalDate
    let time: LocalTime?

    init(day: LocalDate, time: LocalTime? = nil) {
        self.day = day
        self.time = time
    }

    /// Parses `YYYY-MM-DD` or `YYYY-MM-DDTHH:mm[:ss]` (local wall-clock time). A value with an offset is a moment,
    /// not a clock time: see `init(moment:in:)`.
    init?(rawValue: String) {
        guard let written = WrittenTimestamp(rawValue), written.offset == nil else { return nil }
        self.init(day: written.day, time: written.time)
    }

    /// The date and the time of day of a timestamp as it is written, whatever offset follows
    /// (`2026-10-20T09:12:44.123+02:00` → 2026-10-20 09:12): the clock of the place it was written in.
    init?(writtenWallClockOf text: String) {
        guard let written = WrittenTimestamp(text) else { return nil }
        self.init(day: written.day, time: written.time)
    }

    /// A moment written with an offset (`2026-10-23T16:00Z`, as a skill or another app may write a `due`), on the clock of
    /// `calendar`: the offset is converted, not dropped.
    init?(moment text: String, in calendar: Calendar) {
        guard let moment = WrittenTimestamp(text)?.moment else { return nil }
        self.init(day: LocalDate(moment, in: calendar), time: LocalTime(moment, in: calendar))
    }

    var rawValue: String {
        guard let time else { return day.isoString }
        return "\(day.isoString)T\(time.string)"
    }

    func date(in calendar: Calendar) -> Date {
        day.startDate(in: calendar, offset: time ?? .midnight)
    }
}
