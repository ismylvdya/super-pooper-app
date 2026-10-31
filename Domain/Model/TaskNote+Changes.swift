import Foundation

extension TaskNote {
    /// The in-memory result of applying changes (the file is the source of truth; this mirrors it).
    func applying(_ changes: [TaskEdit]) -> TaskNote {
        var task = self
        for change in changes {
            switch change {
            case .status(let value):
                task.status = value
                if value != .done { task.completedDate = nil }
            case .complete(let day):
                task.status = .done
                task.completedDate = day
            case .reopen:
                task.status = .thisWeek
                task.completedDate = nil
            case .highPriority(let value): task.isHighPriority = value
            case .due(let value): task.due = value
            case .timeEstimate(let value): task.timeEstimate = value
            case .addPreviousTask(let name):
                if !task.previousTasks.contains(where: { $0.isSameNoteName(as: name) }) { task.previousTasks.append(name) }
            case .removePreviousTask(let name):
                task.previousTasks.removeAll { $0.isSameNoteName(as: name) }
            case .addProject(let name):
                if !task.projects.contains(where: { $0.isSameNoteName(as: name) }) { task.projects.append(name) }
            case .subtaskOrder(let value): task.subtaskOrder = value
            case .previousEvent(let value): task.previousEvent = value
            case .nextEvent(let value): task.nextEvent = value
            case .feel(let value): task.feel = value
            case .timeZone(let value): task.timeZone = value
            case .mark(let mark, let day): task.marks[day] = mark
            case .recurrence(let rule):
                task.recurrence = rule
                task.hasUnreadableRecurrence = false
            case .reminderTimes(let times): task.reminderTimes = times.sorted()
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
