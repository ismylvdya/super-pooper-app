import Foundation

/// One field edit of a task note. The data layer turns each into a single frontmatter key change.
/// List fields change by deltas (mark one day, add/remove/rename one link): the writer applies
/// them to the freshly read file, so entries added elsewhere meanwhile are never lost.
enum TaskFieldChange: Hashable, Sendable {
    case status(TaskStatus)
    case highPriority(Bool)
    case due(TaskDue?)
    case timeEstimate(Int?)
    case addPreviousTask(String)
    case removePreviousTask(String)
    case renamePreviousTask(from: String, to: String)
    case previousEvent(EventLink?)
    case nextEvent(EventLink?)
    case needEnergy(Bool)
    case pleasant(Bool?)
    /// Exactly one mark (or none) for `day` in the three instance lists.
    case markInstance(day: LocalDate, mark: HabitMark?)
    case completedDate(LocalDate?)
    /// The raw recurrence rule, or `nil` to remove it.
    case recurrence(String?)
    case reminderTimes([LocalTime])
    case habitColor(String?)
    case harmful(Bool)
    case showInToday(Bool)
    case timeOfDay(HabitTimeOfDay?)
    case twiceADay(Bool)
    case twiceCountsDouble(Bool)
    case weeklyGoal(Int?)
    case allowedSkips(Int?)
}

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
            case .previousEvent(let value): task.previousEvent = value
            case .nextEvent(let value): task.nextEvent = value
            case .needEnergy(let value): task.needEnergy = value
            case .pleasant(let value): task.pleasant = value
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

extension String {
    /// Note names match like Obsidian links on Apple platforms: case-insensitive, any Unicode form.
    func isSameNoteName(as other: String) -> Bool {
        lowercased() == other.lowercased()
    }
}
