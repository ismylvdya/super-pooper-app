import Foundation

/// A task dragged over the right part of a list lets go as the subtask of the row above it (`NewItemNesting`): it stands
/// under that task, at `index` among its subtasks, in its list and in today's pool as it is. Not under itself, nor under
/// one of its own subtasks (that would make a loop); a project shown one at a time takes it as a step like any other.
enum SubtaskMove {
    /// The edits that make `task` a subtask of `parent`; nil when it cannot go there.
    static func changes(moving task: TaskItem, under parent: TaskItem, index: Int?, in tasks: [TaskItem]) -> [TaskEdit]? {
        guard !task.isHabit, !task.name.isSameNoteName(as: parent.name), !task.status.isCompleted, !parent.status.isCompleted else { return nil }
        let below = SubtaskCascade.subtasks(of: task, in: tasks, change: .deletion)
        guard !below.contains(where: { $0.name.isSameNoteName(as: parent.name) }) else { return nil }
        var edits: [TaskEdit] = [.parent(parent.name), .subtaskOrder(index)]
        if !parent.isHabit, parent.status != task.status, TaskStatus.open.contains(parent.status) { edits.append(.status(parent.status)) }
        if parent.isInTodayPool != task.isInTodayPool, !parent.isHabit { edits.append(.inTodayPool(parent.isInTodayPool)) }
        return edits
    }
}
