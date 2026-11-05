import Foundation

/// Which tasks belong to the day and in what state.
struct DayMembership: Sendable {
    let occurrence: TaskOccurrence
    let context: DayContext
    /// The parent of each repeatable subtask, by the subtask's name (`RepeatableSubtasks.parents`).
    var parents: [NoteName: TaskItem] = [:]

    /// Today: habits of the day shown in Today (not skipped, or already marked), this week's tasks not dated later and
    /// what was completed today. A repeatable subtask is in when its parent is, skipped or not, unless skipped itself.
    func isInDay(_ task: TaskItem, skipped: Set<String>) -> Bool {
        if task.isHabit {
            guard task.isInTodayHabits, !skipped.containsNoteName(task.name) else { return false }
            return comesUpToday(task) || task.mark(on: context.today) != nil
        }
        return (task.status.isThisWeek && !isDatedLater(task) && !task.waitsInList)
            || (task.status == .done && task.completedDate == context.today)
    }

    /// Another day mirrors the file: what has a line dated that day. This week's tasks dated it, and the habits shown in
    /// Today whose nearest day it is: one still open today stands on today, not on the days after.
    func isOnOtherDay(_ task: TaskItem) -> Bool {
        if task.isHabit { return task.isInTodayHabits && hasLineOnDay(task) }
        guard task.status.isThisWeek, let due = task.due else { return false }
        return context.logicalDay(of: due) == context.today
    }

    func state(of task: TaskItem) -> DayItemState {
        if task.isHabit {
            return task.mark(on: context.today).map(DayItemState.marked) ?? .open
        }
        return task.status == .done ? .marked(.done) : .open
    }

    /// A habit by its own rule or marked today; a repeatable subtask whenever its parent comes up.
    private func comesUpToday(_ task: TaskItem, depth: Int = 0) -> Bool {
        guard let parent = parent(of: task, depth: depth) else {
            return occurrence.occurs(task, on: context.today) || task.isOverdue || (depth > 0 && task.mark(on: context.today) != nil)
        }
        return parent.isInTodayHabits && comesUpToday(parent, depth: depth + 1)
    }

    /// A repeatable subtask has no line of its own: it goes by its parent's.
    private func hasLineOnDay(_ task: TaskItem, depth: Int = 0) -> Bool {
        guard let parent = parent(of: task, depth: depth) else {
            return task.nextLine.map { context.logicalDay(of: $0) == context.today } ?? false
        }
        return parent.isInTodayHabits && hasLineOnDay(parent, depth: depth + 1)
    }

    /// Parents of parents are followed up to the number of subtasks there are, so a loop of parents ends.
    private func parent(of task: TaskItem, depth: Int) -> TaskItem? {
        depth <= parents.count ? parents[task.name.noteName] : nil
    }

    /// A task dated after today (Tomorrow, a day of next week) waits for its day, even this week.
    /// An overdue one stays in today.
    private func isDatedLater(_ task: TaskItem) -> Bool {
        guard let due = task.due else { return false }
        return context.logicalDay(of: due) > context.today
    }
}
