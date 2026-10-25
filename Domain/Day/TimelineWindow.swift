import Foundation

/// The time range a timeline column shows.
struct TimelineWindow: Hashable, Sendable {
    let start: Date
    let end: Date

    static let hour: TimeInterval = 3600

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var hours: Double { duration / Self.hour }

    /// The hour height that fits the window into `height`; a window shorter than an hour counts as one.
    func hourHeight(fitting height: Double) -> Double { height / max(hours, 1) }

    /// Points from the start of the window to `date` at `hourHeight`.
    func offset(of date: Date, hourHeight: Double) -> Double { date.timeIntervalSince(start) / Self.hour * hourHeight }

    func contains(_ date: Date) -> Bool { date >= start && date <= end }

    /// One wide column from "now − before" to "now + after", widened to whole hours.
    static func rolling(now: Date, hoursBefore: Int, hoursAfter: Int, calendar: Calendar) -> TimelineWindow {
        let start = calendar.dateInterval(of: .hour, for: now.addingTimeInterval(-Double(hoursBefore) * hour))?.start ?? now
        let endBase = now.addingTimeInterval(Double(hoursAfter) * hour)
        let hour = calendar.dateInterval(of: .hour, for: endBase)
        let end = hour.map { $0.start == endBase ? endBase : $0.end } ?? endBase
        return TimelineWindow(start: start, end: end)
    }

    /// A fixed part of today (e.g. 06:00–14:00). An end before the start means "after midnight".
    static func fixed(start: LocalTime, end: LocalTime, context: DayContext) -> TimelineWindow {
        let startDate = context.date(context.today, start)
        let endDay = end <= start ? context.today.adding(days: 1) : context.today
        return TimelineWindow(start: startDate, end: context.date(endDay, end))
    }
}
