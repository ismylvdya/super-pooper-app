import Foundation

/// Which task notes a list of the Lists tab holds: tasks (no habits) at the chosen planning levels and with the
/// chosen properties, by name; grouped by planning level for the weekly review.
struct TaskListFilter: Hashable, Sendable {
    var statuses: [TaskStatus] = TaskStatus.open
    var feel: TaskFeel?
    var maxEstimate: Int?

    func matches(_ task: TaskNote, rules: DayRules) -> Bool {
        guard !task.isHabit, statuses.contains(task.status) else { return false }
        if let feel, task.feel != feel { return false }
        if let maxEstimate, rules.estimate(of: task) > maxEstimate { return false }
        return true
    }

    /// The matching tasks whose names contain `query`, in name order, grouped by planning level in `statuses` order.
    func groups(of tasks: [TaskNote], query: String, rules: DayRules) -> [(status: TaskStatus, tasks: [TaskNote])] {
        let found = NameOrder.sorted(tasks.filter { matches($0, rules: rules) && SearchMatcher.matches($0.name, query) })
        return statuses.compactMap { status in
            let members = found.filter { $0.status == status }
            return members.isEmpty ? nil : (status, members)
        }
    }

    /// A list of done tasks also shows the done folder (done tasks are filed there at once).
    var showsFiled: Bool { statuses.contains(.done) }

    /// What the list holds: the matching tasks and, for a list of done ones, the done folder's tasks whose names contain
    /// `query`, newest first.
    func contents(of tasks: [TaskNote], filed: [TaskNote], query: String, rules: DayRules) -> TaskListContents {
        let filed = showsFiled ? filed.filter { SearchMatcher.matches($0.name, query) } : []
        return TaskListContents(groups: groups(of: tasks, query: query, rules: rules),
                                filed: filed.sorted { ($0.completedDate?.isoString ?? "") > ($1.completedDate?.isoString ?? "") })
    }
}

/// The tasks of one list of the Lists tab, by planning level, and the done folder's ones.
struct TaskListContents: Sendable {
    let groups: [(status: TaskStatus, tasks: [TaskNote])]
    let filed: [TaskNote]

    var count: Int { groups.reduce(0) { $0 + $1.tasks.count } + filed.count }
    var isEmpty: Bool { count == 0 }
}
