import Foundation

/// The kinds of entries the timeline shows (Settings → Timeline).
struct TimelineFilter: Codable, Equatable, Sendable {
    var events = true
    var reminders = true
    /// Tasks with a time today.
    var tasks = true
    /// Habits with reminder times.
    var habits = true

    func shows(_ item: DayItem) -> Bool {
        item.isHabit ? habits : tasks
    }
}
