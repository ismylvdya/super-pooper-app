import Foundation

/// "Not today", one rule for the pool menu and the swipe in This week: an open task (not a habit, which has Skip today)
/// leaves today and stays this week.
enum NotToday {
    static func isAvailable(for item: DayItem) -> Bool {
        !item.isHabit && !item.isDone
    }

    /// A task with a time (it sits on the timeline) moves to the same time on the next logical day: 01:00 tonight
    /// still belongs to today, so it goes to 01:00 the night after. Without a time nothing is written; the task only
    /// leaves today (see `AppModel.postpone`).
    static func changes(for task: TaskNote, context: DayContext) -> [TaskFieldChange] {
        guard !task.isHabit, let time = task.due?.time else { return [] }
        return [.due(context.due(onLogicalDay: context.today.adding(days: 1), time: time))]
    }
}
