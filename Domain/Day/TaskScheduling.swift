import Foundation

/// Dragging a task between the pool and the timeline. Dropped on the timeline it gets a `due` with the
/// date and time of that spot (and with it a notification); dragged back to the pool it keeps its date
/// and loses the time. A habit's note is never changed by a drag (its times apply to every day): its block moves on
/// the shown day's timeline or to the pool for that day only (`TodayTimes`).
enum TaskScheduling {
    /// A drag writes the note (tasks).
    static func canMove(_ task: TaskItem) -> Bool { !task.isHabit }

    /// A dragged item can land on the shown day's timeline: a task; a habit's block from the timeline (`slot`: its time
    /// as the note has it); a habit from the pool only with a reminder time sent there that day.
    static func canPlace(_ task: TaskItem, slot: LocalTime?, today: TodayTimes) -> Bool {
        canMove(task) || slot != nil || !today.pooled(of: task).isEmpty
    }

    /// A block dragged from the timeline can land in the pool: a task (it loses its time) or a habit's block (today only).
    static func canSendToPool(_ task: TaskItem, slot: LocalTime?) -> Bool {
        canMove(task) || slot != nil
    }

    static func changes(scheduling task: TaskItem, at moment: Date, calendar: Calendar) -> [TaskEdit] {
        guard canMove(task) else { return [] }
        return [.due(TaskDue(day: LocalDate(moment, in: calendar), time: LocalTime(moment, in: calendar)))]
    }

    /// Keeps the logical day: a task at 00:30 goes back to tonight's date, not tomorrow's.
    static func changes(unscheduling task: TaskItem, context: DayContext) -> [TaskEdit] {
        guard canMove(task), let due = task.due, due.time != nil else { return [] }
        return [.due(TaskDue(day: context.logicalDay(of: due)))]
    }

    /// Where a "+" let go, or a hold, at `offset` points below the top of a timeline window puts a new item: the moment
    /// there on the drop step, as a dragged task would get it.
    static func placement(atOffset offset: Double, windowStart: Date, hourHeight: Double, stepMinutes: Int,
                          calendar: Calendar) -> NewItemPlacement {
        .timeline(at: moment(atOffset: offset, windowStart: windowStart, hourHeight: hourHeight, stepMinutes: stepMinutes,
                             calendar: calendar), calendar: calendar)
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
