import Foundation

/// What the screens show that is worked out from the tasks: habits in the user's order, the archive, the lists of the
/// Lists tab, a note's subtasks and Next tasks.
extension AppModel {
    /// The mark tasks stand after in lists and search: the emoji the task tag starts with (🔫 for `🔫делишка`).
    var taskMark: String? { TagEmoji.leading(of: settings.vault.taskTag) }

    /// Active habits in the user's order; the rest alphabetically after them.
    var habits: [TaskItem] {
        HabitOrder.sorted(tasks.filter { $0.isHabit && !$0.isArchived }, order: settings.habits.order)
    }

    var archivedTasks: [TaskItem] { NameOrder.sorted(tasks.filter { $0.isArchived && !$0.isHabit }) }
    var archivedHabits: [TaskItem] { NameOrder.sorted(tasks.filter { $0.isHabit && $0.isArchived }) }
    var archivedNotesCount: Int { archivedTasks.count + archivedHabits.count }

    /// The tasks that wait for `name`, by name: its Next tasks.
    func nextTasks(of name: String) -> [String] {
        NameOrder.sorted(NameReferences.waiting(for: name, in: tasks).map(\.name))
    }

    /// Subtasks of a note (notes whose `projects` link to it), in their order.
    func subtasks(of parent: String) -> [TaskItem] { parts.tasks.subtasks(of: parent) }

    // MARK: - Lists tab

    /// What a list holds now, the filed tasks included.
    func listContents(_ listID: String, query: String) -> TaskListContents { parts.lists.contents(of: listID, query: query) }
    func listContents(_ filter: TaskListFilter, query: String) -> TaskListContents { parts.lists.contents(filter, query: query) }
    func listCount(_ listID: String) -> Int { parts.lists.count(of: listID) }

    /// The Lists tab shows: the filed tasks are read for the counts of the lists of done tasks.
    func loadFiledTasks() async { await parts.lists.loadFiled() }

    /// A list opens: the filed tasks are read when it shows them.
    func openList(_ listID: String) async { await parts.lists.open(listID) }
}
