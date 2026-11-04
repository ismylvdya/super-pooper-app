import Foundation

/// Turns moments into the user's logical days: a moment before the day boundary belongs to the day before
/// (a habit created in Obsidian at 01:00 starts on the evening's day, not on the next one).
struct DayBoundary: Sendable {
    let calendar: Calendar
    let boundary: LocalTime

    func day(of date: Date) -> LocalDate {
        DayContext.logicalDay(of: date, calendar: calendar, boundary: boundary)
    }

    /// The logical day of a wall-clock date and time (`due` 01:00 on the 24th → the 23rd with a 04:00 boundary).
    func day(of written: TaskDue) -> LocalDate {
        written.logicalDay(boundary: boundary)
    }
}

extension TaskDue {
    /// The logical day this date and time belong to: a time before the boundary is still the day before.
    func logicalDay(boundary: LocalTime) -> LocalDate {
        guard let time, time < boundary else { return day }
        return day.adding(days: -1)
    }
}
