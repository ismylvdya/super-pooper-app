import Foundation

/// Turns check-offs and status choices into edits: a regular task is completed on today or reopened; a recurring one
/// gets one mark for the day. The one way to change a status: every place that moves a task asks `changes(setting:on:)`.
struct TaskMarking: Sendable {
    let today: LocalDate

    /// `day` matters for habits only (marks for past days); a regular task is simply done or not.
    func changes(marking task: TaskItem, as mark: HabitMark?, on day: LocalDate? = nil) -> [TaskEdit] {
        if task.isHabit {
            let day = day ?? today
            return task.mark(on: day) == mark ? [] : [.mark(mark, on: day)]
        }
        if mark != nil {
            return task.status == .done ? [] : [.complete(on: today)]
        }
        return task.status == .done ? [.reopen] : []
    }

    /// Tap: open → done, done → open.
    func changes(toggling task: TaskItem) -> [TaskEdit] {
        let isMarked = task.isHabit ? task.mark(on: today) != nil : task.status == .done
        return changes(marking: task, as: isMarked ? nil : .done)
    }

    /// A status change (the task page, the review, the archive and its restore, promotion to this week): entering done
    /// completes the task today; any other status leaves done. Recurring tasks only change the status.
    func changes(setting status: TaskStatus, on task: TaskItem) -> [TaskEdit] {
        guard status != task.status else { return [] }
        return status == .done && !task.isHabit ? [.complete(on: today)] : [.status(status)]
    }
}
