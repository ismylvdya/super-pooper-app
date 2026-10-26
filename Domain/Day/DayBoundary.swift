import Foundation

/// Turns moments into the user's logical days: a moment before the day boundary belongs to the day before
/// (a habit created in Obsidian at 01:00 starts on the evening's day, not on the next one).
struct DayBoundary: Sendable {
    let calendar: Calendar
    let boundary: LocalTime

    func day(of date: Date) -> LocalDate {
        DayContext.logicalDay(of: date, calendar: calendar, boundary: boundary)
    }
}
