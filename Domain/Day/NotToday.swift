import Foundation

/// Not today for an open task: it leaves today's pool (`TodayPool`) and keeps its date and its list; the day's turn
/// brings it back by the rule. One with a time today goes to the same time tomorrow. A habit has its own, through its line.
enum NotToday {
    static func isAvailable(for item: DayItem) -> Bool {
        !item.isHabit && !item.isDone
    }

    static func changes(for task: TaskItem, context: DayContext) -> [TaskEdit] {
        guard let due = task.due, due.time != nil, context.logicalDay(of: due) == context.today else { return [.inTodayPool(false)] }
        return [.due(TaskDue(day: due.day.adding(days: 1), time: due.time)), .inTodayPool(false)]
    }
}
