import Foundation

/// The events a task can be linked to: the anchor events from now until `daysAhead` days on whose titles contain the
/// query, by day.
enum EventPicking {
    struct Day: Equatable, Sendable {
        let day: LocalDate
        let events: [CalendarEvent]
    }

    static func days(_ events: [CalendarEvent], matching query: String, daysAhead: Int, context: DayContext) -> [Day] {
        let calendar = context.calendar
        let end = context.today.adding(days: daysAhead).startDate(in: calendar)
        let candidates = events.filter { $0.end > context.now && $0.start < end && SearchMatcher.matches($0.title, query) }
        let days = Set(candidates.map { LocalDate($0.start, in: calendar) }).sorted()
        return days.map { day in Day(day: day, events: candidates.filter { LocalDate($0.start, in: calendar) == day }) }
    }
}
