import Foundation

/// What a backlog page left of the pool holds for the day shown: Soon, this week's tasks the day does not show (in its
/// pool or on its timeline); a later planning level, its tasks. Tasks only, in the store's order.
enum BacklogContents {
    static func tasks(at level: TaskStatus, in tasks: [TaskItem], plan: DayPlan, rules: DayRules) -> [TaskItem] {
        let shown = plan.pool.map(\.id) + plan.timeline.compactMap(\.taskItem).map(\.id)
        let filter = TaskListFilter(statuses: [level])
        return NameOrder.sorted(tasks.filter { filter.matches($0, rules: rules) && !shown.containsNoteName($0.name) }).inStoreOrder
    }
}

private extension TimelineSlot {
    var taskItem: DayItem? {
        if case .task(let item) = content { item } else { nil }
    }
}
