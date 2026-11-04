import Foundation

/// Which task notes a list of the Lists tab holds: tasks (no habits) at the chosen planning levels and with the
/// chosen properties, in the store's order; grouped by planning level for the weekly review.
struct TaskListFilter: Hashable, Sendable {
    var statuses: [TaskStatus] = TaskStatus.open
    var feel: TaskFeel?
    var maxEstimate: Int?

    func matches(_ task: TaskItem, rules: DayRules) -> Bool {
        guard !task.isHabit, statuses.contains(task.status.planningLevel) else { return false }
        if let feel, task.feel != feel { return false }
        if let maxEstimate, rules.estimate(of: task) > maxEstimate { return false }
        return true
    }

    /// The matching tasks whose names contain `query`, in the store's order, grouped by planning level in `statuses` order.
    func groups(of tasks: [TaskItem], query: String, rules: DayRules) -> [(status: TaskStatus, tasks: [TaskItem])] {
        let found = NameOrder.sorted(tasks.filter { matches($0, rules: rules) && SearchMatcher.matches($0.name, query) }).inStoreOrder
        return statuses.compactMap { status in
            let members = found.filter { $0.status.planningLevel == status }
            return members.isEmpty ? nil : (status, members)
        }
    }

    /// A list of done tasks also shows the filed ones (done tasks are filed away at once).
    var showsFiled: Bool { statuses.contains(.done) }

    /// What the list holds: the matching tasks and, for a list of done ones, the filed tasks whose names contain
    /// `query`, newest first.
    func contents(of tasks: [TaskItem], filed: [TaskItem], query: String, rules: DayRules) -> TaskListContents {
        let filed = showsFiled ? filed.filter { SearchMatcher.matches($0.name, query) } : []
        return TaskListContents(groups: groups(of: tasks, query: query, rules: rules),
                                filed: filed.sorted { ($0.completedDate?.isoString ?? "") > ($1.completedDate?.isoString ?? "") },
                                namesLevels: statuses.count > 1)
    }
}

/// The tasks of one list of the Lists tab, by planning level, and the filed ones.
struct TaskListContents: Sendable {
    let groups: [(status: TaskStatus, tasks: [TaskItem])]
    let filed: [TaskItem]
    /// The groups are titled by their planning level; a list of one level already says it in its title.
    let namesLevels: Bool

    var count: Int { groups.reduce(0) { $0 + $1.tasks.count } + filed.count }
    var isEmpty: Bool { count == 0 }
}

extension [TaskItem] {
    /// As the store's lines stand; a stable sort, so what has no place stays after them in the order it had.
    var inStoreOrder: [TaskItem] {
        enumerated().sorted { first, second in
            switch (first.element.storeOrder, second.element.storeOrder) {
            case let (one?, other?) where one != other: one < other
            case (_?, nil): true
            case (nil, _?): false
            default: first.offset < second.offset
            }
        }.map(\.element)
    }
}
