import Foundation

/// Dragging a task between the pool and the timeline. Dropped on the timeline it gets a `due` with the
/// date and time of that spot (and with it a notification); dragged back to the pool it keeps its date
/// and loses the time. Habits stay where their rule puts them: a time would apply to every day of theirs.
enum TaskScheduling {
    static func canMove(_ task: TaskNote) -> Bool { !task.isHabit }

    static func changes(scheduling task: TaskNote, at moment: Date, calendar: Calendar) -> [TaskFieldChange] {
        guard canMove(task) else { return [] }
        let parts = calendar.dateComponents([.hour, .minute], from: moment)
        let time = LocalTime(minutesSinceMidnight: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
        return [.due(TaskDue(day: LocalDate(moment, in: calendar), time: time))]
    }

    /// Keeps the logical day: a task at 00:30 goes back to tonight's date, not tomorrow's.
    static func changes(unscheduling task: TaskNote, context: DayContext) -> [TaskFieldChange] {
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
