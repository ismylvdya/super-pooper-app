import Foundation

/// Another day than today (swiped to on Today): only what is planned for that very day — its events and
/// reminders, and tasks whose date is that day. No habits, no this-week pool.
enum OtherDay {
    /// The tasks of `day`, made to look like this-week tasks so the day logic places them.
    static func tasks(_ tasks: [TaskNote], on day: LocalDate, context: DayContext) -> [TaskNote] {
        tasks.compactMap { task in
            guard !task.isHabit, !task.status.isCompleted, let due = task.due, context.logicalDay(of: due) == day else { return nil }
            var planned = task
            planned.status = .thisWeek
            return planned
        }
    }

    /// "Now" inside another day: the hour the timeline centres on (no cursor is drawn).
    static func moment(of day: LocalDate, context: DayContext, anchor: LocalTime) -> Date {
        context.moment(anchor, onLogicalDay: day)
    }
}
