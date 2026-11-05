import Foundation

/// What a task dragged onto a backlog page (Next actions, Soon, Someday), or from one into a day, becomes. Times are the
/// day's view of the task (on the phone's clock).
enum BacklogMoves {
    struct Outcome: Equatable, Sendable {
        var edits: [TaskEdit] = []
    }

    /// Onto the page of `level`. Into Next actions: from the shown day the date goes; from a later level it becomes this week's,
    /// and a date that has come goes too, so it waits there. Onto a later level: that level.
    static func onto(_ level: TaskStatus, task: TaskItem, fromShownDay: Bool, shown: LocalDate,
                     context: DayContext) -> Outcome {
        guard level.isThisWeek else {
            return Outcome(edits: TaskMarking(today: context.today).changes(setting: level, on: task))
        }
        if fromShownDay { return Outcome(edits: task.due == nil ? [] : [.due(nil)]) }
        let hasCome = task.due.map { context.logicalDay(of: $0) <= context.today } ?? false
        return Outcome(edits: thisWeek(task, context: context) + (hasCome ? [.due(nil)] : []))
    }

    /// From a backlog page into the pool of `day`: this week's, dated that day without a time. A task already on that day
    /// keeps its date.
    static func intoPool(_ task: TaskItem, day: LocalDate, context: DayContext) -> Outcome {
        var edits = thisWeek(task, context: context)
        if task.due.map({ context.logicalDay(of: $0) != day }) ?? true { edits.append(.due(TaskDue(day: day))) }
        return Outcome(edits: edits)
    }

    /// From a backlog page onto a timeline: this week's, at the time it was dropped at.
    static func ontoTimeline(_ task: TaskItem, at moment: Date, context: DayContext) -> Outcome {
        let time = TaskScheduling.changes(scheduling: task, at: moment, calendar: context.calendar)
        return Outcome(edits: thisWeek(task, context: context) + time)
    }

    private static func thisWeek(_ task: TaskItem, context: DayContext) -> [TaskEdit] {
        task.status.isThisWeek ? [] : TaskMarking(today: context.today).changes(setting: .thisWeek, on: task)
    }
}
