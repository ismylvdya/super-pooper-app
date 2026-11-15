import Foundation

/// What a backlog page left of the pool holds for the day shown: the tasks of its planning level, dated or not (a date
/// is a deadline). Never what the day shows (in its pool or on its timeline). Tasks only, in the store's order.
enum BacklogContents {
    static func tasks(at level: TaskStatus, in tasks: [TaskItem], plan: DayPlan, rules: DayRules) -> [TaskItem] {
        let shown = plan.pool.map(\.id) + plan.timeline.compactMap(\.taskItem).map(\.id)
        let filter = TaskListFilter(statuses: [level])
        let waiting = TaskSteps.waiting(in: tasks)
        let held = tasks.filter { filter.matches($0, rules: rules) && !shown.containsNoteName($0.name) && !waiting.contains($0.name) }
        return NameOrder.sorted(held).inStoreOrder
    }
}

private extension TimelineSlot {
    var taskItem: DayItem? {
        if case .task(let item) = content { item } else { nil }
    }
}
