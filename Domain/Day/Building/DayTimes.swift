import Foundation

/// When a task stands on the day's timeline.
struct DayTimes: Sendable {
    let context: DayContext
    /// Habit blocks dragged today (to another time or to the pool).
    var habitTimes = HabitDayTimes()

    /// Habits are planned at their reminder times as today has them; other tasks need `due` with a time on today's
    /// logical day.
    func times(of task: TaskItem) -> [BlockTime] {
        if task.isHabit { return habitTimes.blocks(of: task) }
        guard let due = task.due, let time = due.time, context.logicalDay(of: due) == context.today else { return [] }
        return [BlockTime(time)]
    }

    /// The blocks still to do today. A closed day leaves the timeline (Twice closes it however many reminders there
    /// are); before that a habit with several blocks loses one per mark, earliest first (Done the first one); one with a
    /// single block keeps it until the day is closed (twice a day waits for Twice).
    func openTimes(of item: DayItem) -> [BlockTime] {
        guard !item.isFinished else { return [] }
        let times = times(of: item.task)
        guard item.isHabit, times.count > 1 else { return times }
        let ordered = times.sorted { moment(of: $0) < moment(of: $1) }
        return Array(ordered.dropFirst(HabitMarking.timesClosed(by: item.state.mark)))
    }

    /// A habit with reminder times sent to the pool today stands in the pool too, while its day is open.
    func isPooledToday(_ item: DayItem) -> Bool {
        item.isHabit && !item.isFinished && !habitTimes.pooled(of: item.task).isEmpty
    }

    /// The moment a block starts at today.
    func moment(of block: BlockTime) -> Date {
        context.moment(block.time, onLogicalDay: context.today)
    }

    /// The first open block of a timed task or habit today: what a chain hangs on. `start`: where an overdue task's block
    /// stands now (`OverdueTasks`), if it is not at its own time.
    func target(of item: DayItem, rules: DayRules, start: Date? = nil) -> TimelineChain.Target? {
        guard let block = openTimes(of: item).first else { return nil }
        return TimelineChain.Target(id: TimelineContent.task(item).id,
                                    end: (start ?? moment(of: block)).addingTimeInterval(rules.duration(of: item.task)))
    }

    func overlapsToday(_ event: CalendarEvent) -> Bool {
        event.start < context.dayEnd && event.end > context.dayStart
    }
}
