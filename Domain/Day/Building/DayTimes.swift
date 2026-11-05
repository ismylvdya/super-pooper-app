import Foundation

/// When a task stands on the day's timeline.
struct DayTimes: Sendable {
    let context: DayContext
    /// Blocks moved today (dragged to another time or to the pool, or snoozed).
    var todayTimes = TodayTimes()
    /// Another day: a habit whose line there has no time waits in that day's pool.
    var followsLines = false

    /// Habits are planned at their reminder times as today has them; other tasks need `due` with a time on today's
    /// logical day, moved as today has it.
    func times(of task: TaskItem) -> [BlockTime] {
        if task.isHabit {
            if followsLines, let line = task.nextLine, line.time == nil { return [] }
            return todayTimes.blocks(of: task)
        }
        guard let due = task.due, let time = due.time, context.logicalDay(of: due) == context.today else { return [] }
        return todayTimes.blocks(of: task, written: [time])
    }

    /// The blocks still to do today. A closed day leaves the timeline (Twice closes it however many reminders there
    /// are); before that a habit with several blocks loses one per mark, earliest first (Done the first one), counting
    /// the blocks sent to the pool, which stand there for the later ones; one with a single block keeps it until the day
    /// is closed (twice a day waits for Twice).
    func openTimes(of item: DayItem) -> [BlockTime] {
        guard !item.isFinished else { return [] }
        let times = times(of: item.task)
        guard item.isHabit, times.count + todayTimes.pooled(of: item.task).count > 1 else { return times }
        let ordered = times.sorted { moment(of: $0) < moment(of: $1) }
        return Array(ordered.dropFirst(HabitMarking.timesClosed(by: item.state.mark)))
    }

    /// A habit with reminder times sent to the pool today stands in the pool too, while its day is open.
    func isPooledToday(_ item: DayItem) -> Bool {
        item.isHabit && !item.isFinished && !todayTimes.pooled(of: item.task).isEmpty
    }

    /// The moment a block starts at today.
    func moment(of block: BlockTime) -> Date {
        context.moment(block.time, onLogicalDay: context.today)
    }

    func overlapsToday(_ event: CalendarEvent) -> Bool {
        event.start < context.dayEnd && event.end > context.dayStart
    }
}
