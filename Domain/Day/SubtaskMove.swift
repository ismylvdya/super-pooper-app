import Foundation

/// A task carried under another item lets go as its subtask (`NewItemNesting`): it stands under that item — a task or a
/// habit, done or not — at `index` among its subtasks, in its list and in today's pool as it is. Not under itself, nor
/// under one of its own subtasks (that would make a loop); a project shown one at a time takes it as a step like any
/// other. A habit itself stays out of families.
enum SubtaskMove {
    /// The edits that make `task` a subtask of `parent`; nil when it cannot go there.
    static func changes(moving task: TaskItem, under parent: TaskItem, index: Int?, in tasks: [TaskItem]) -> [TaskEdit]? {
        guard !task.isHabit, !task.name.isSameNoteName(as: parent.name) else { return nil }
        let below = SubtaskCascade.subtasks(of: task, in: tasks, change: .deletion)
        guard !below.contains(where: { $0.name.isSameNoteName(as: parent.name) }) else { return nil }
        var edits: [TaskEdit] = [.parent(parent.name), .subtaskOrder(index)]
        if !parent.isHabit, parent.status != task.status, TaskStatus.open.contains(parent.status) { edits.append(.status(parent.status)) }
        if parent.isInTodayPool != task.isInTodayPool, !parent.isHabit { edits.append(.inTodayPool(parent.isInTodayPool)) }
        return edits
    }
}
