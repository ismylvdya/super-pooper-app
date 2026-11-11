import Foundation

/// The parent a row names over its own: a subtask's, when its parent is not among the rows shown with it.
enum ShownParent {
    static func parent(of task: TaskItem, shown: Set<NoteName>) -> String? {
        guard let parent = task.projects.first, !parent.isSameNoteName(as: task.name), !shown.contains(parent.noteName) else { return nil }
        return parent
    }
}
