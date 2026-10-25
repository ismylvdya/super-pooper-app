import Foundation

/// Which task notes a list of the Lists tab holds: tasks (no habits) at the chosen planning levels and with the
/// chosen properties, by name; grouped by planning level for the weekly review.
struct TaskListFilter: Hashable, Sendable {
    static let openStatuses: [TaskStatus] = [.thisWeek, .halfYear, .someday, .waiting]

    var statuses: [TaskStatus] = openStatuses
    var pleasant: Bool?
    var needEnergy: Bool?
    var maxEstimate: Int?

    func matches(_ task: TaskNote, rules: DayRules) -> Bool {
        guard !task.isHabit, statuses.contains(task.status) else { return false }
        if let pleasant, (task.pleasant ?? false) != pleasant { return false }
        if let needEnergy, task.needEnergy != needEnergy { return false }
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
}
