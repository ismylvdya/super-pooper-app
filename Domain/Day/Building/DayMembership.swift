import Foundation

/// Which tasks belong to the day and in what state.
struct DayMembership: Sendable {
    let occurrence: TaskOccurrence
    let context: DayContext

    /// Today: habits of the day shown in Today (not skipped, or already marked), this week's tasks not dated later and
    /// what was completed today.
    func isInDay(_ task: TaskItem, skipped: Set<String>) -> Bool {
        if task.isHabit {
            guard task.isInTodayHabits, !skipped.containsNoteName(task.name) else { return false }
            return occurrence.occurs(task, on: context.today) || task.mark(on: context.today) != nil
        }
        return (task.status == .thisWeek && !isDatedLater(task))
            || (task.status == .done && task.completedDate == context.today)
    }

    /// Another day: the habits shown in Today that repeat on it, this week's tasks dated that day.
    func isOnOtherDay(_ task: TaskItem) -> Bool {
        if task.isHabit { return task.isInTodayHabits && occurrence.occurs(task, on: context.today) }
        guard task.status == .thisWeek, let due = task.due else { return false }
        return context.logicalDay(of: due) == context.today
    }

    func state(of task: TaskItem) -> DayItemState {
        if task.isHabit {
            return task.mark(on: context.today).map(DayItemState.marked) ?? .open
        }
        return task.status == .done ? .marked(.done) : .open
    }

    /// A task dated after today (Tomorrow, a day of next week) waits for its day, even this week.
    /// An overdue one stays in today.
    private func isDatedLater(_ task: TaskItem) -> Bool {
        guard let due = task.due else { return false }
        return context.logicalDay(of: due) > context.today
    }
}
