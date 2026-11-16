import Foundation

/// A row of a list moved one tab right or left (the swipe to the right, D-182). Right, a task of the top level: under the
/// row above it — as that row's subtask when it is a task of the top level, or beside it under its parent when it is a
/// subtask itself (one tab, never a subtask of a subtask). Left, a subtask: one level up, standing right after its old
/// parent; from the first level it is a task of its own.
enum SubtaskIndent {
    /// One tab right: `rows` are the list's rows as shown (depths and all), `name` one of them. Nil when it cannot go.
    static func indent(_ name: String, rows: [DayItem], tasks: [TaskItem]) -> [TaskEdit]? {
        guard let at = rows.firstIndex(where: { $0.id.isSameNoteName(as: name) }), at > 0, rows[at].depth == 0,
              let task = task(named: name, in: tasks), task.projects.isEmpty else { return nil }
        let above = rows[at - 1]
        let parentName: String
        let index: Int?
        if above.depth == 0 {
            parentName = above.id
            index = nil
        } else {
            guard let parent = above.task.projects.first else { return nil }
            parentName = parent
            // Right after the row above among their parent's subtasks.
            index = rows[..<at].filter { $0.depth == above.depth && $0.task.projects.first?.isSameNoteName(as: parent) == true }.count
        }
        guard let parent = self.task(named: parentName, in: tasks) else { return nil }
        return SubtaskMove.changes(moving: task, under: parent, index: index, in: tasks)
    }

    /// One tab left: the parent it leaves, and the edits. Under a parent of its own the old parent's parent takes it,
    /// right after the old parent; the old parent's parent none, it is a task of its own (the caller puts its line right
    /// after the old parent's).
    static func outdent(_ name: String, tasks: [TaskItem]) -> (parent: String, edits: [TaskEdit])? {
        guard let task = task(named: name, in: tasks), !task.isHabit, let parentName = task.projects.first,
              let parent = self.task(named: parentName, in: tasks) else { return nil }
        guard let grand = parent.projects.first else { return (parent.name, [.parent(nil), .subtaskOrder(nil)]) }
        let siblings = SubtaskOrder.stable(tasks.filter { $0.projects.first?.isSameNoteName(as: grand) == true })
        let after = (siblings.firstIndex { $0.name.isSameNoteName(as: parent.name) } ?? siblings.count - 1) + 1
        return (parent.name, [.parent(grand), .subtaskOrder(after)])
    }

    /// The top level's order with `name` right after `parent`: what the lines of `tasks` of one list become.
    static func order(placing name: String, after parent: String, among tasks: [TaskItem]) -> [String] {
        var names = tasks.filter { $0.projects.isEmpty || $0.name.isSameNoteName(as: name) }
            .sorted { ($0.storeOrder ?? .max) < ($1.storeOrder ?? .max) }.map(\.name)
        names.removeAll { $0.isSameNoteName(as: name) }
        let spot = (names.firstIndex { $0.isSameNoteName(as: parent) } ?? names.count - 1) + 1
        names.insert(name, at: spot)
        return names
    }

    private static func task(named name: String, in tasks: [TaskItem]) -> TaskItem? {
        tasks.first { $0.name.isSameNoteName(as: name) }
    }
}
