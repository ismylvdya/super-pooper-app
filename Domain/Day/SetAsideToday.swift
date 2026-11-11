import Foundation

/// What was taken out of today and can come back, at the bottom of the morning review: tasks put off with Not today
/// (they wait in Next actions without a date) and habits skipped today. A step waiting for an earlier one of a task
/// shown one at a time is not put off: it is not up yet (`TaskSteps`).
enum SetAsideToday {
    static func notes(in tasks: [TaskItem], skipped: [String]) -> [TaskItem] {
        let waiting = TaskSteps.waiting(in: tasks)
        let found = tasks.filter { task in
            if task.isHabit { return task.isInTodayHabits && skipped.containsNoteName(task.name) }
            return task.status.isThisWeek && task.waitsInList && !waiting.contains(task.name)
        }
        return NameOrder.sorted(found)
    }
}
