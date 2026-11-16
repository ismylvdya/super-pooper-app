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

    /// Subtasks of a note (notes whose `projects` link to it), in their order.
    func subtasks(of parent: String) -> [TaskItem] { parts.tasks.subtasks(of: parent) }

    /// A habit's or a repeatable task's subtask: it comes up on its parent's days and has no rule of its own to edit.

    /// How many subtasks an action on the note takes along (Delete, Done; the delete confirmation says so).
    func subtasksGoingAlong(with name: String, action: ActionID) -> Int {
        guard let change = action.subtaskChange, let task = task(named: name) else { return 0 }
        return SubtaskCascade.subtasks(of: task, in: tasks, change: change).count
    }

    // MARK: - Lists tab

    /// The icon of the button to the lists, as picked in the settings.
    var tabBarSymbols: TabBarSymbols { TabBarSymbols(typed: settings.tabBar.symbols, icons: config.icons) }
    var listsIcon: Icon { config.lists.icon(for: settings.lists.icon) }

    /// What a list holds now, the filed tasks included.
    func listContents(_ listID: String, query: String) -> TaskListContents { parts.lists.contents(of: listID, query: query) }
    func listContents(_ filter: TaskListFilter, query: String) -> TaskListContents { parts.lists.contents(filter, query: query) }
    func listCount(_ listID: String) -> Int { parts.lists.count(of: listID) }

    /// Taken out of today and able to come back: put off with Not today, or skipped (`SetAsideToday`).
    var setAsideToday: [TaskItem] {
        let context = parts.day.context()
        return SetAsideToday.notes(in: tasks, skipped: parts.day.skippedNames, today: context.today, boundary: context.boundary)
    }

    // MARK: - The review's Tomorrow

    /// Tomorrow as the morning review plans it today.
    func tomorrowPlan() -> DayPlan { parts.derived.tomorrowPlan(at: clock.now) }

    /// Kept out of tomorrow: the tasks marked so that tomorrow's turn would bring, and the habits skipped in tomorrow's plan.
    var setAsideTomorrow: [TaskItem] {
        let context = parts.day.context()
        let tomorrow = context.today.adding(days: 1)
        let skipped = parts.day.tomorrow.skipped
        let habits = tasks.filter { $0.isInTodayHabits && skipped.containsNoteName($0.name) }
        return NameOrder.sorted(TodayPool.keptOutTomorrow(tasks, tomorrow: tomorrow, boundary: context.boundary) + habits)
    }

    /// Tomorrow's order was set by hand in the review.
    var tomorrowHasManualOrder: Bool { parts.day.tomorrow.manualOrder != nil }

    func applyTomorrowMove(_ move: ReviewGroups.Move) { parts.dayCommands.applyTomorrowMove(move) }
    func resetTomorrowOrder() { parts.dayCommands.resetTomorrowOrder() }
    func markTomorrowReviewed() { parts.dayCommands.markTomorrowReviewed() }

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
