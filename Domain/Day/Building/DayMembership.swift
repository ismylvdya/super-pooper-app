import Foundation

/// Which tasks belong to the day and in what state.
struct DayMembership: Sendable {
    let occurrence: TaskOccurrence
    let context: DayContext

    /// Today: habits of the day shown in Today (not skipped, or already marked), the tasks of Next actions in today's pool
    /// (`TodayPool`), the tasks with a time today (on the timeline) and what was completed today.
    func isInDay(_ task: TaskItem, skipped: Set<String>) -> Bool {
        if task.isHabit {
            guard task.isInTodayHabits, !skipped.containsNoteName(task.name) else { return false }
            return comesUpToday(task) || task.dayMark(on: context.today) != nil
        }
        let isOpen = TaskStatus.open.contains(task.status)
        return (task.status.isThisWeek && task.isInTodayPool) || (isOpen && isTimedToday(task))
            || (task.status == .done && task.completedDate == context.today)
    }

    /// Another day mirrors the file: what has a line dated that day. The tasks dated it, and the habits shown in Today
    /// whose nearest day it is: one still open today stands on today, not on the days after; one overdue today stands on
    /// the next day of its rule too.
    func isOnOtherDay(_ task: TaskItem) -> Bool {
        if task.isHabit { return task.isInTodayHabits && hasLineOnDay(task) }
        guard TaskStatus.open.contains(task.status), let due = task.due else { return false }
        return context.logicalDay(of: due) == context.today
    }

    func state(of task: TaskItem) -> DayItemState {
        if task.isHabit {
            return task.dayMark(on: context.today).map(DayItemState.marked) ?? .open
        }
        return task.status == .done ? .marked(.done) : .open
    }

    /// A habit by its own rule, carried over overdue, or marked today.
    private func comesUpToday(_ task: TaskItem) -> Bool {
        occurrence.occurs(task, on: context.today) || task.isOverdue
    }

    /// Its open line stands on the day; an overdue line stands on the real today, and the habit comes up again on the
    /// next day of its rule.
    private func hasLineOnDay(_ task: TaskItem) -> Bool {
        guard let line = task.nextLine else { return false }
        let lineDay = context.logicalDay(of: line)
        if lineDay == context.today { return true }
        guard task.isOverdue, lineDay < context.today else { return false }
        let next = occurrence.schedule(of: task).recurrence?.firstDay(onOrAfter: lineDay.adding(days: 1)) ?? lineDay.adding(days: 1)
        return next == context.today
    }

    /// A task with a time today stands on today's timeline by that time.
    private func isTimedToday(_ task: TaskItem) -> Bool {
        guard let due = task.due, due.time != nil else { return false }
        return context.logicalDay(of: due) == context.today
    }
}
