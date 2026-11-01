import Foundation

/// What goes with a parent (.1965): deleting it or completing it takes its subtasks along, and theirs, all the way down.
/// A subtask that also belongs to another parent that stays open (not going along, neither done nor archived) is left
/// alone. Reopening takes nothing along: a parent opened again does not bring its subtasks back.
enum SubtaskCascade {
    enum Change: Sendable {
        case deletion
        case completion
    }

    /// The subtasks that go with `parent`, each after its own parent. A completion writes only open tasks (habits are
    /// marked per day, never completed), yet it reaches down through subtasks done before.
    static func subtasks(of parent: TaskItem, in tasks: [TaskItem], change: Change) -> [TaskItem] {
        var going = [parent]
        var grew = true
        while grew {
            grew = false
            for task in tasks where !going.contains(where: { $0.id == task.id }) && joins(task, going: going, tasks: tasks) {
                going.append(task)
                grew = true
            }
        }
        let subtasks = Array(going.dropFirst())
        switch change {
        case .deletion: return subtasks
        case .completion: return subtasks.filter { !$0.isHabit && $0.status != .done }
        }
    }

    /// A subtask of a note going along, none of whose other parents stays open.
    private static func joins(_ task: TaskItem, going: [TaskItem], tasks: [TaskItem]) -> Bool {
        let isGoing = { (name: String) in going.contains { $0.name.isSameNoteName(as: name) } }
        guard task.projects.contains(where: isGoing) else { return false }
        return !task.projects.contains { name in
            !isGoing(name) && !name.isSameNoteName(as: task.name)
                && tasks.contains { $0.name.isSameNoteName(as: name) && $0.status != .done && !$0.isArchived }
        }
    }
}

extension ActionID {
    /// What the action does to the subtasks of the note it is on: Delete deletes them, Done completes them.
    var subtaskChange: SubtaskCascade.Change? {
        switch self {
        case .delete: .deletion
        case .done: .completion
        default: nil
        }
    }
}
