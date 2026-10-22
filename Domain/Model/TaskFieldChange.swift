import Foundation

/// One field edit of a task note. The data layer turns each into a single frontmatter key change.
enum TaskFieldChange: Hashable, Sendable {
    case status(TaskStatus)
    case highPriority(Bool)
    case due(TaskDue?)
    case timeEstimate(Int?)
    case previousTasks([String])
    case previousEvent(EventLink?)
    case nextEvent(EventLink?)
    case needEnergy(Bool)
    case pleasant(Bool?)
    case habitInstances(HabitInstances)
    case completedDate(LocalDate?)
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
            case .previousTasks(let value): task.previousTasks = value
            case .previousEvent(let value): task.previousEvent = value
            case .nextEvent(let value): task.nextEvent = value
            case .needEnergy(let value): task.needEnergy = value
            case .pleasant(let value): task.pleasant = value
            case .habitInstances(let value):
                task.completeInstances = value.complete
                task.partialInstances = value.partial
                task.twiceInstances = value.twice
            case .completedDate(let value): task.completedDate = value
            }
        }
        return task
    }
}
