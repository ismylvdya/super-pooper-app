import Foundation

/// What was taken out of today and can come back, at the bottom of the morning review: tasks the day's turn would bring
/// into the pool (`TodayPool.isDue`) that are not in it — put off with Not today, or added during the day — and habits
/// skipped today. A step waiting for an earlier one of a task shown one at a time is not put off: it is not up yet
/// (`TaskSteps`).
enum SetAsideToday {
    static func notes(in tasks: [TaskItem], skipped: [String], today: LocalDate, boundary: LocalTime) -> [TaskItem] {
        let waiting = TaskSteps.waiting(in: tasks)
        let found = tasks.filter { task in
            if task.isHabit { return task.isInTodayHabits && skipped.containsNoteName(task.name) }
            return !task.isInTodayPool && TodayPool.isDue(task, today: today, boundary: boundary, waiting: waiting)
        }
        return NameOrder.sorted(found)
    }
}
