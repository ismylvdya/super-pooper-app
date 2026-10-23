import Foundation

/// Finds non-recurring tasks from the backlog whose `due` falls within the current week
/// (today through Sunday); they move to `this_week`. Statuses are never lowered.
struct AutoPromoter: Sendable {
    let promotableStatuses: Set<TaskStatus>

    func candidates(in tasks: [TaskNote], context: DayContext) -> [TaskNote] {
        tasks.filter { task in
            guard !task.isHabit, promotableStatuses.contains(task.status), let day = task.due?.day else { return false }
            return day >= context.today && day <= context.weekEnd
        }
    }
}
