import Foundation

/// Subtasks of a habit or a repeatable task: repeatable themselves, with no rule of their own. They come up in the days
/// their parent does, are marked Done or skipped for each day apart from it, and stay off the Habits list. Their note
/// carries the parent's rule (copied when created, rewritten when the parent's changes) so TaskNotes shows them sensibly.
enum RepeatableSubtasks {
    /// The habit `task` is a subtask of, if `task` is a habit too; nil for a one-off subtask or a note of its own.
    static func parent(of task: TaskItem, in tasks: [TaskItem]) -> TaskItem? {
        guard task.isHabit else { return nil }
        return task.projects.lazy.compactMap { name in
            tasks.first { $0.isHabit && $0.name.isSameNoteName(as: name) && !$0.name.isSameNoteName(as: task.name) }
        }.first
    }

    static func isRepeatableSubtask(_ task: TaskItem, in tasks: [TaskItem]) -> Bool {
        parent(of: task, in: tasks) != nil
    }

    /// The parent of each repeatable subtask among `tasks`, by the subtask's name.
    static func parents(in tasks: [TaskItem]) -> [NoteName: TaskItem] {
        var result: [NoteName: TaskItem] = [:]
        for task in tasks {
            if let parent = parent(of: task, in: tasks) { result[task.name.noteName] = parent }
        }
        return result
    }

    /// The edits that give each repeatable subtask of `parent` the parent's rule; nothing when the parent has none or a
    /// subtask has it already.
    static func followingRule(of parent: TaskItem, in tasks: [TaskItem]) -> [(name: String, edits: [TaskEdit])] {
        guard let rule = parent.recurrence else { return [] }
        return tasks
            .filter { $0.recurrence != rule && self.parent(of: $0, in: tasks)?.id == parent.id }
            .map { (name: $0.name, edits: [.recurrence(rule)]) }
    }
}
