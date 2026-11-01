import Foundation

/// Dragging a task between the pool and the timeline. Dropped on the timeline it gets a `due` with the
/// date and time of that spot (and with it a notification); dragged back to the pool it keeps its date
/// and loses the time. A habit's note is never changed by a drag (its times apply to every day): its block moves on
/// today's timeline or to the pool for today only (`HabitDayTimes`).
enum TaskScheduling {
    /// A drag writes the note (tasks).
    static func canMove(_ task: TaskItem) -> Bool { !task.isHabit }

    /// A timeline block can be picked up: a task's on any day shown, a habit's only on today's timeline.
    static func canDrag(_ task: TaskItem, isToday: Bool) -> Bool { canMove(task) || isToday }

    /// A dragged item can land on today's timeline: a task; a habit's block from the timeline (`slot`: its time as the
    /// note has it); a habit from the pool only with a reminder time sent there today.
    static func canPlace(_ task: TaskItem, slot: LocalTime?, today: HabitDayTimes) -> Bool {
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

    /// The moment at `offset` points below the top of a timeline window, on a multiple of `stepMinutes`.
    static func moment(atOffset offset: Double, windowStart: Date, hourHeight: Double, stepMinutes: Int, calendar: Calendar) -> Date {
        let raw = windowStart.addingTimeInterval(max(offset, 0) / max(hourHeight, 1) * TimelineWindow.hour)
        let step = Double(max(stepMinutes, 1) * 60)
        let dayStart = calendar.startOfDay(for: raw)
        let seconds = (raw.timeIntervalSince(dayStart) / step).rounded() * step
        return dayStart.addingTimeInterval(seconds)
    }
}
