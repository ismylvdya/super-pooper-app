import Foundation

/// A field of a task or habit by the domain's name: what a value that cannot be read, or a change made both here and
/// elsewhere, is about. The store knows where it keeps each one; screens put it in words.
enum TaskField: String, CaseIterable, Hashable, Codable, Sendable {
    case status, priority, due, timeEstimate, projects, subtaskOrder, feel
    case recurrence, marks, completedDate, created, modified, reminderTimes, timeZone
    case habitColor, harmful, repeatable, showInToday, timeOfDay, twiceADay, twiceCountsDouble, weeklyGoal, allowedSkips
}

extension TaskEdit {
    /// The field the edit changes: the one table from edits to fields.
    var field: TaskField {
        switch self {
        case .status, .complete, .reopen: .status
        case .highPriority: .priority
        case .due: .due
        case .timeEstimate: .timeEstimate
        case .addProject: .projects
        case .subtaskOrder: .subtaskOrder
        case .feel: .feel
        case .mark: .marks
        case .recurrence: .recurrence
        case .reminderTimes: .reminderTimes
        case .timeZone: .timeZone
        case .habitColor: .habitColor
        case .harmful: .harmful
        case .repeatable: .repeatable
        case .showInToday: .showInToday
        case .timeOfDay: .timeOfDay
        case .twiceADay: .twiceADay
        case .twiceCountsDouble: .twiceCountsDouble
        case .weeklyGoal: .weeklyGoal
        case .allowedSkips: .allowedSkips
        }
    }

    /// A delta on a list (one link, one day's mark): it merges with what changed elsewhere and never clashes.
    var mergesByItself: Bool {
        switch self {
        case .addProject, .mark: true
        default: false
        }
    }
}

extension TaskItem {
    /// The value of a field, for telling whether it changed.
    func value(of field: TaskField) -> AnyHashable? {
        switch field {
        case .status: status
        case .priority: isHighPriority
        case .due: due
        case .timeEstimate: timeEstimate
        case .projects: projects
        case .subtaskOrder: subtaskOrder
        case .feel: feel
        case .recurrence: recurrence
        case .marks: marks
        case .completedDate: completedDate
        case .created: created
        case .modified: dateModified
        case .reminderTimes: reminderTimes
        case .timeZone: timeZone
        case .habitColor: habit.color
        case .harmful: habit.harmful
        case .repeatable: habit.repeatable
        case .showInToday: habit.showInToday
        case .timeOfDay: habit.timeOfDay
        case .twiceADay: habit.twiceADay
        case .twiceCountsDouble: habit.twiceCountsDouble
        case .weeklyGoal: habit.weeklyGoal
        case .allowedSkips: habit.allowedSkips
        }
    }
}
