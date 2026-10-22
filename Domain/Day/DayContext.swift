import Foundation

/// Everything time-related the day logic needs: "now", the calendar (with an explicit time zone)
/// and the user's day boundary and energy hour. The logical day starts at `boundary`, so at 02:00
/// it is still "yesterday".
struct DayContext: Sendable {
    let now: Date
    let calendar: Calendar
    let boundary: LocalTime
    let energyHour: LocalTime
    let today: LocalDate

    init(now: Date, calendar: Calendar, boundary: LocalTime, energyHour: LocalTime) {
        self.now = now
        self.calendar = calendar
        self.boundary = boundary
        self.energyHour = energyHour
        let shifted = now.addingTimeInterval(-Double(boundary.minutesSinceMidnight) * 60)
        self.today = LocalDate(shifted, in: calendar)
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

    /// The logical day a dated task belongs to (`due` 01:00 on the 24th → the 23rd with a 04:00 boundary).
    func logicalDay(of due: TaskDue) -> LocalDate {
        guard let time = due.time, time < boundary else { return due.day }
        return due.day.adding(days: -1)
    }

    func with(now: Date) -> DayContext {
        DayContext(now: now, calendar: calendar, boundary: boundary, energyHour: energyHour)
    }

    func contains(_ date: Date) -> Bool { date >= dayStart && date < dayEnd }
}
