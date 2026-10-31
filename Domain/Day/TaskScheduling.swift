import Foundation

/// Dragging a task between the pool and the timeline. Dropped on the timeline it gets a `due` with the
/// date and time of that spot (and with it a notification); dragged back to the pool it keeps its date
/// and loses the time. Habits stay where their rule puts them: a time would apply to every day of theirs.
enum TaskScheduling {
    static func canMove(_ task: TaskItem) -> Bool { !task.isHabit }

    static func changes(scheduling task: TaskItem, at moment: Date, calendar: Calendar) -> [TaskEdit] {
        guard canMove(task) else { return [] }
        return [.due(TaskDue(day: LocalDate(moment, in: calendar), time: LocalTime(moment, in: calendar)))]
    }

    /// Keeps the logical day: a task at 00:30 goes back to tonight's date, not tomorrow's.
    static func changes(unscheduling task: TaskItem, context: DayContext) -> [TaskEdit] {
        guard canMove(task), let due = task.due, due.time != nil else { return [] }
        return [.due(TaskDue(day: context.logicalDay(of: due)))]
    }

    /// The moment at `offset` points below the top of a timeline window, on a multiple of `stepMinutes`.
    static func moment(atOffset offset: Double, windowStart: Date, hourHeight: Double, stepMinutes: Int, calendar: Calendar) -> Date {
        let raw = windowStart.addingTimeInterval(max(offset, 0) / max(hourHeight, 1) * TimelineWindow.hour)
        let step = Double(max(stepMinutes, 1) * 60)
        let dayStart = calendar.startOfDay(for: raw)
        let seconds = (raw.timeIntervalSince(dayStart) / step).rounded() * step
        return dayStart.addingTimeInterval(seconds)
    }
}
