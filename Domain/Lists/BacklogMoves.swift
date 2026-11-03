import Foundation

/// What a task dragged onto a backlog page (Soon, Half year, Someday), or from one into a day, becomes. Times are the
/// day's view of the task (on the phone's clock).
enum BacklogMoves {
    struct Outcome: Equatable, Sendable {
        var edits: [TaskEdit] = []
        /// Today's Not today (`NotToday`): the task leaves today's pool or timeline.
        var isNotToday = false
        /// Kept out of today's pool until tomorrow: dropped in Soon, it stays there.
        var postpones = false
        /// Back among today's tasks if it was kept out.
        var unpostpones = false
    }

    /// Onto the page of `level` while the day `shown` is shown. `fromShownDay`: it came from that day's pool or timeline.
    /// Into Soon from today = Not today; from another day the date goes; from a later level it becomes this week's and,
    /// shown today, waits in Soon until tomorrow rather than landing in today's pool. Onto a later level: that level.
    static func onto(_ level: TaskStatus, task: TaskItem, fromShownDay: Bool, shown: LocalDate,
                     context: DayContext) -> Outcome {
        guard level.isThisWeek else {
            return Outcome(edits: TaskMarking(today: context.today).changes(setting: level, on: task), unpostpones: true)
        }
        if fromShownDay {
            return shown == context.today ? Outcome(isNotToday: true) : Outcome(edits: task.due == nil ? [] : [.due(nil)])
        }
        let landsToday = shown == context.today && task.due.map { context.logicalDay(of: $0) <= context.today } ?? true
        return Outcome(edits: thisWeek(task, context: context), postpones: landsToday)
    }

    /// From a backlog page into the pool of `day`: this week's; today without a date (one of another day goes), another
    /// day dated that day without a time.
    static func intoPool(_ task: TaskItem, day: LocalDate, context: DayContext) -> Outcome {
        var edits = thisWeek(task, context: context)
        if day == context.today {
            if let due = task.due, context.logicalDay(of: due) != day { edits.append(.due(nil)) }
            return Outcome(edits: edits, unpostpones: true)
        }
        if task.due != TaskDue(day: day) { edits.append(.due(TaskDue(day: day))) }
        return Outcome(edits: edits)
    }

    /// From a backlog page onto a timeline: this week's, at the time it was dropped at.
    static func ontoTimeline(_ task: TaskItem, at moment: Date, context: DayContext) -> Outcome {
        let time = TaskScheduling.changes(scheduling: task, at: moment, calendar: context.calendar)
        return Outcome(edits: thisWeek(task, context: context) + time, unpostpones: true)
    }

    private static func thisWeek(_ task: TaskItem, context: DayContext) -> [TaskEdit] {
        task.status.isThisWeek ? [] : TaskMarking(today: context.today).changes(setting: .thisWeek, on: task)
    }
}
