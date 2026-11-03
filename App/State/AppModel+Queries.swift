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

    /// A habit's or a repeatable task's subtask: it comes up on its parent's days and has no rule of its own to edit.
    func isRepeatableSubtask(_ task: TaskItem) -> Bool { RepeatableSubtasks.isRepeatableSubtask(task, in: tasks) }

    /// How many subtasks an action on the note takes along (Delete, Done; the delete confirmation says so).
    func subtasksGoingAlong(with name: String, action: ActionID) -> Int {
        guard let change = action.subtaskChange, let task = task(named: name) else { return 0 }
        return SubtaskCascade.subtasks(of: task, in: tasks, change: change).count
    }

    // MARK: - Lists tab

    /// The icon of the button to the lists, as picked in the settings.
    var listsIcon: Icon { config.lists.icon(for: settings.lists.icon) }

    /// What a list holds now, the filed tasks included.
    func listContents(_ listID: String, query: String) -> TaskListContents { parts.lists.contents(of: listID, query: query) }
    func listContents(_ filter: TaskListFilter, query: String) -> TaskListContents { parts.lists.contents(filter, query: query) }
    func listCount(_ listID: String) -> Int { parts.lists.count(of: listID) }

    // MARK: - Backlog pages

    /// The pages left of the pool on Tasks, nearest to the pool first.
    var backlogLists: [BacklogList] { config.lists.backlogLists }

    /// What a backlog page holds for the day `plan` shows (`BacklogContents`).
    func backlogTasks(_ list: BacklogList, plan: DayPlan) -> [TaskItem] {
        BacklogContents.tasks(at: list.status, in: tasks, plan: plan, rules: config.rules.day)
    }

    /// The Lists tab shows: the filed tasks are read for the counts of the lists of done tasks.
    func loadFiledTasks() async { await parts.lists.loadFiled() }

    /// A list opens: the filed tasks are read when it shows them.
    func openList(_ listID: String) async { await parts.lists.open(listID) }
}
