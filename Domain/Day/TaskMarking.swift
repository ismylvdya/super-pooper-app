import Foundation

/// Turns check-off actions into field changes, following TaskNotes conventions:
/// a regular task gets `status: done` + `completed_date`; a recurring one gets today's date in
/// `complete_instances` (plus `partial_instances` / `twice_instances` for those marks).
struct TaskMarking: Sendable {
    let today: LocalDate

    func changes(marking task: TaskNote, as mark: HabitMark?) -> [TaskFieldChange] {
        if task.isRecurring {
            let current = HabitInstances(task: task)
            let updated = current.setting(mark, on: today)
            return updated == current ? [] : [.habitInstances(updated)]
        }
        if mark != nil {
            return task.status == .done ? [] : [.status(.done), .completedDate(today)]
        }
        return task.status == .done ? [.status(.thisWeek), .completedDate(nil)] : []
    }

    /// Tap: open → done, done → open.
    func changes(toggling task: TaskNote) -> [TaskFieldChange] {
        let isMarked = task.isRecurring ? HabitInstances(task: task).mark(on: today) != nil : task.status == .done
        return changes(marking: task, as: isMarked ? nil : .done)
    }

    /// A status change from the task page or the review: entering `done` sets `completed_date`
    /// (as TaskNotes does), leaving it removes the date. Recurring tasks only change the status.
    func changes(setting status: TaskStatus, on task: TaskNote) -> [TaskFieldChange] {
        guard status != task.status else { return [] }
        var result: [TaskFieldChange] = [.status(status)]
        guard !task.isRecurring else { return result }
        if status == .done { result.append(.completedDate(today)) } else if task.status == .done { result.append(.completedDate(nil)) }
        return result
    }
}
