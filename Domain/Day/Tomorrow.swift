import Foundation

/// Tomorrow, one rule for an open task and for what the day leaves unfinished: it goes to the next logical day's pool, with no
/// time and marked overdue. A habit does the same through its line, unless its own rule has that day (`waitingHabitLines`).
enum Tomorrow {
    static func isAvailable(for item: DayItem) -> Bool {
        !item.isHabit && !item.isDone
    }

    static func changes(for task: TaskItem, context: DayContext) -> [TaskEdit] {
        [.due(TaskDue(day: context.today.adding(days: 1))), .overdue(true)]
    }
}
