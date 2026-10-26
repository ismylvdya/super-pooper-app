import Foundation

/// Which of the keys an edit writes were also changed elsewhere since the app read the note.
/// List edits are deltas (marks, links) and merge by themselves; only single-value keys can clash.
enum WriteConflict {
    static func keys(_ changes: [TaskFieldChange], seen: TaskNote, latest: TaskNote, mapping: FieldMapping) -> [String] {
        var result: [String] = []
        for change in changes {
            guard let (key, value) = field(change, mapping: mapping) else { continue }
            if value(seen) != value(latest), !result.contains(key) { result.append(key) }
        }
        return result
    }

    /// The frontmatter key a change writes and how to read that field from a note.
    private static func field(_ change: TaskFieldChange, mapping: FieldMapping) -> (String, (TaskNote) -> AnyHashable?)? {
        let keys = mapping.fields
        switch change {
        case .status: return (keys.status, { $0.status })
        case .highPriority: return (keys.priority, { $0.isHighPriority })
        case .due: return (keys.due, { $0.due })
        case .timeEstimate: return (keys.timeEstimate, { $0.timeEstimate })
        case .previousEvent: return (keys.previousEvent, { $0.previousEvent })
        case .nextEvent: return (keys.nextEvent, { $0.nextEvent })
        case .needEnergy: return (keys.needEnergy, { $0.needEnergy })
        case .pleasant: return (keys.pleasant, { $0.pleasant })
        case .completedDate: return (keys.completedDate, { $0.completedDate })
        case .recurrence: return (keys.recurrence, { $0.recurrenceRaw })
        case .reminderTimes: return (keys.reminderTimes, { $0.reminderTimes })
        case .habitColor: return (keys.habitColor, { $0.habit.color })
        case .harmful: return (keys.harmful, { $0.habit.harmful })
        case .repeatable: return (keys.repeatable, { $0.habit.repeatable })
        case .showInToday: return (keys.showInToday, { $0.habit.showInToday })
        case .timeOfDay: return (keys.timeOfDay, { $0.habit.timeOfDay })
        case .twiceADay: return (keys.twiceADay, { $0.habit.twiceADay })
        case .twiceCountsDouble: return (keys.twiceCountsDouble, { $0.habit.twiceCountsDouble })
        case .weeklyGoal: return (keys.weeklyGoal, { $0.habit.weeklyGoal })
        case .allowedSkips: return (keys.allowedSkips, { $0.habit.allowedSkips })
        case .subtaskOrder: return (keys.subtaskOrder, { $0.subtaskOrder })
        case .addPreviousTask, .removePreviousTask, .renamePreviousTask, .addProject, .renameProject, .markInstance: return nil
        }
    }
}
