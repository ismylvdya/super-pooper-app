import Foundation

/// Everything time-related the day logic needs: "now", the calendar (with an explicit time zone)
/// and the user's day boundary and energy hour. The logical day starts at `boundary`, so at 02:00
/// it is still "yesterday". `focus` is the moment the day is seen around: now for today, the anchor hour of
/// another day browsed on Today; `today` is the logical day of the focus, while "past" and blocking use `now`.
struct DayContext: Sendable {
    let now: Date
    let focus: Date
    let calendar: Calendar
    let boundary: LocalTime
    let energyHour: LocalTime
    let today: LocalDate

    init(now: Date, calendar: Calendar, boundary: LocalTime, energyHour: LocalTime, focus: Date? = nil) {
        self.now = now
        self.focus = focus ?? now
        self.calendar = calendar
        self.boundary = boundary
        self.energyHour = energyHour
        self.today = Self.logicalDay(of: focus ?? now, calendar: calendar, boundary: boundary)
    }

    /// Wall-clock time before the boundary belongs to the previous date. Compared on the clock face, not by
    /// subtracting hours, so the nights the clocks change keep the boundary where it is.
    static func logicalDay(of date: Date, calendar: Calendar, boundary: LocalTime) -> LocalDate {
        let day = LocalDate(date, in: calendar)
        return LocalTime(date, in: calendar) < boundary ? day.adding(days: -1) : day
    }

    var dayStart: Date { today.startDate(in: calendar, offset: boundary) }
    var dayEnd: Date { today.adding(days: 1).startDate(in: calendar, offset: boundary) }

    /// Sunday of the current ISO week (inclusive end of "this week").
    var weekEnd: LocalDate { today.adding(days: Weekday.sunday.rawValue - today.weekday.rawValue) }

    var isBeforeEnergyHour: Bool { now < date(today, energyHour) }

    func date(_ day: LocalDate, _ time: LocalTime) -> Date { day.startDate(in: calendar, offset: time) }

    /// The moment of `time` within logical `day`: times before the boundary are after midnight.
    func moment(_ time: LocalTime, onLogicalDay day: LocalDate) -> Date {
        time < boundary ? date(day.adding(days: 1), time) : date(day, time)
    }

    /// The logical day of a moment (a notification at 01:30 belongs to the evening before).
    func logicalDay(of date: Date) -> LocalDate {
        Self.logicalDay(of: date, calendar: calendar, boundary: boundary)
    }

    /// The logical day a dated task belongs to (`due` 01:00 on the 24th → the 23rd with a 04:00 boundary).
    func logicalDay(of due: TaskDue) -> LocalDate {
        guard let time = due.time, time < boundary else { return due.day }
        return due.day.adding(days: -1)
    }

    /// A date and time on logical `day`: a time before the boundary falls on the next date.
    func due(onLogicalDay day: LocalDate, time: LocalTime?) -> TaskDue {
        guard let time, time < boundary else { return TaskDue(day: day, time: time) }
        return TaskDue(day: day.adding(days: 1), time: time)
    }

    func with(now: Date) -> DayContext {
        DayContext(now: now, calendar: calendar, boundary: boundary, energyHour: energyHour)
    }

    /// The same now, seen around `moment` (another day).
    func focused(on moment: Date) -> DayContext {
        DayContext(now: now, calendar: calendar, boundary: boundary, energyHour: energyHour, focus: moment)
    }

    func contains(_ date: Date) -> Bool { date >= dayStart && date < dayEnd }
}
