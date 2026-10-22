import Foundation

/// The time range a timeline column shows.
struct TimelineWindow: Hashable, Sendable {
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }

    func contains(_ date: Date) -> Bool { date >= start && date <= end }

    /// One wide column from "now − before" to "now + after", widened to whole hours.
    static func rolling(now: Date, hoursBefore: Int, hoursAfter: Int, calendar: Calendar) -> TimelineWindow {
        let start = calendar.dateInterval(of: .hour, for: now.addingTimeInterval(-Double(hoursBefore) * 3600))?.start ?? now
        let endBase = now.addingTimeInterval(Double(hoursAfter) * 3600)
        let end = calendar.dateInterval(of: .hour, for: endBase)?.end ?? endBase
        return TimelineWindow(start: start, end: end)
    }

    /// A fixed part of today (e.g. 06:00–14:00). An end before the start means "after midnight".
    static func fixed(start: LocalTime, end: LocalTime, context: DayContext) -> TimelineWindow {
        let startDate = context.date(context.today, start)
        let endDay = end <= start ? context.today.adding(days: 1) : context.today
        return TimelineWindow(start: startDate, end: context.date(endDay, end))
    }
}
