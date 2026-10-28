import Foundation

extension TaskNote {
    /// The in-memory result of applying changes (the file is the source of truth; this mirrors it).
    func applying(_ changes: [TaskFieldChange]) -> TaskNote {
        var task = self
        for change in changes {
            switch change {
            case .status(let value): task.status = value
            case .highPriority(let value): task.isHighPriority = value
            case .due(let value): task.due = value
            case .timeEstimate(let value): task.timeEstimate = value
            case .addPreviousTask(let name):
                if !task.previousTasks.contains(where: { $0.isSameNoteName(as: name) }) { task.previousTasks.append(name) }
            case .removePreviousTask(let name):
                task.previousTasks.removeAll { $0.isSameNoteName(as: name) }
            case .renamePreviousTask(let old, let new):
                task.previousTasks = task.previousTasks.map { $0.isSameNoteName(as: old) ? new : $0 }
            case .addProject(let name):
                if !task.projects.contains(where: { $0.isSameNoteName(as: name) }) { task.projects.append(name) }
            case .renameProject(let old, let new):
                task.projects = task.projects.map { $0.isSameNoteName(as: old) ? new : $0 }
            case .subtaskOrder(let value): task.subtaskOrder = value
            case .previousEvent(let value): task.previousEvent = value
            case .nextEvent(let value): task.nextEvent = value
            case .feel(let value): task.feel = value
            case .timeZone(let value): task.timeZone = value
            case .migrateLegacyFields: task.hasLegacyFields = false
            case .markInstance(let day, let mark):
                let instances = HabitInstances(task: task).setting(mark, on: day)
                task.completeInstances = instances.complete
                task.partialInstances = instances.partial
                task.twiceInstances = instances.twice
            case .completedDate(let value): task.completedDate = value
            case .recurrence(let raw):
                task.recurrenceRaw = raw
                task.recurrence = raw.flatMap { try? RecurrenceRule.parse($0).get() }
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
