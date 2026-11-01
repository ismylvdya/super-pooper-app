import Foundation

/// When a task stands on the day's timeline.
struct DayTimes: Sendable {
    let context: DayContext

    /// Habits are planned at their reminder times; other tasks need `due` with a time on today's logical day.
    func times(of task: TaskItem) -> [LocalTime] {
        if task.isHabit { return task.habitTimes }
        guard let due = task.due, let time = due.time, context.logicalDay(of: due) == context.today else { return [] }
        return [time]
    }

    /// The times still to do today. A closed day leaves the timeline (Twice closes it however many reminders there
    /// are); before that a habit with several reminders loses one block per mark, earliest first (Done the first
    /// one); one with a single time keeps it until the day is closed (twice a day waits for Twice).
    func openTimes(of item: DayItem) -> [LocalTime] {
        guard !item.isFinished else { return [] }
        let times = times(of: item.task)
        guard item.isHabit, times.count > 1 else { return times }
        let ordered = times.sorted { context.moment($0, onLogicalDay: context.today) < context.moment($1, onLogicalDay: context.today) }
        return Array(ordered.dropFirst(HabitMarking.timesClosed(by: item.state.mark)))
    }

    /// The first open block of a timed task or habit today: what a chain hangs on.
    func target(of item: DayItem, rules: DayRules) -> TimelineChain.Target? {
        guard let time = openTimes(of: item).first else { return nil }
        let start = context.moment(time, onLogicalDay: context.today)
        return TimelineChain.Target(id: TimelineContent.task(item).id, end: start.addingTimeInterval(rules.duration(of: item.task)))
    }

    func overlapsToday(_ event: CalendarEvent) -> Bool {
        event.start < context.dayEnd && event.end > context.dayStart
    }
}
