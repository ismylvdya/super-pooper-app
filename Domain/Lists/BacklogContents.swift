import Foundation

/// What a backlog page left of the pool holds for the day shown: Next actions, this week's tasks without a date (a date
/// puts a task in that day's pool); a later planning level, its tasks. Never what the day shows (in its pool or on its
/// timeline). Tasks only, in the store's order.
enum BacklogContents {
    static func tasks(at level: TaskStatus, in tasks: [TaskItem], plan: DayPlan, rules: DayRules) -> [TaskItem] {
        let shown = plan.pool.map(\.id) + plan.timeline.compactMap(\.taskItem).map(\.id)
        let filter = TaskListFilter(statuses: [level])
        let held = tasks.filter { filter.matches($0, rules: rules) && !shown.containsNoteName($0.name) && (!level.isThisWeek || $0.due == nil) }
        return NameOrder.sorted(held).inStoreOrder
    }
}

private extension TimelineSlot {
    var taskItem: DayItem? {
        if case .task(let item) = content { item } else { nil }
    }
}
