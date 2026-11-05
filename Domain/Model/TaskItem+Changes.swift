import Foundation

extension TaskItem {
    /// The in-memory result of applying changes (the file is the source of truth; this mirrors it).
    func applying(_ changes: [TaskEdit]) -> TaskItem {
        var task = self
        for change in changes {
            switch change {
            case .status(let value):
                // Coming from another list, undated, it waits in Next actions; only a date brings it into a day.
                if value.isThisWeek, !task.status.isThisWeek, task.due == nil { task.waitsInList = true }
                task.status = value
                if value != .done { task.completedDate = nil }
            case .complete(let day):
                task.status = .done
                task.completedDate = day
            case .reopen:
                task.status = .thisWeek
                task.completedDate = nil
            case .highPriority(let value): task.isHighPriority = value
            case .overdue(let value): task.isOverdue = value
            case .started(let value): task.isStarted = value
            case .waiting(let value): task.isWaiting = value
            case .due(let value):
                task.due = value
                task.isOverdue = false
                task.waitsInList = value == nil
                // A task's alarm is of its time: with the time it goes.
                if value?.time == nil, !task.isHabit { task.alarms = [] }
            case .timeEstimate(let value): task.timeEstimate = value
            case .addProject(let name):
                if !task.projects.contains(where: { $0.isSameNoteName(as: name) }) { task.projects.append(name) }
            case .subtaskOrder(let value): task.subtaskOrder = value
            case .feel(let value): task.feel = value
            case .timeZone(let value): task.timeZone = value
            case .mark(let mark, let day): task.marks[day] = mark
            case .recurrence(let rule):
                task.recurrence = rule
                task.hasUnreadableRecurrence = false
            case .reminderTimes(let times): task.reminderTimes = times.sorted()
            case .alarms(let value): task.alarms = value
            case .habitColor(let value): task.habit.color = value
            case .harmful(let value): task.habit.harmful = value
            case .repeatable(let value): task.habit.repeatable = value
            case .showInToday(let value): task.habit.showInToday = value
            case .timeOfDay(let value): task.habit.timeOfDay = value
            case .twiceADay(let value): task.habit.twiceADay = value
            case .twiceCountsDouble(let value): task.habit.twiceCountsDouble = value
            case .weeklyGoal(let value): task.habit.weeklyGoal = value
            case .allowedSkips(let value): task.habit.allowedSkips = value
            }
        }
        return task
    }
}
