import Foundation

/// A habit's reminder times. They take the place of an older-style time of day in `due`, which goes when they are set.
enum HabitReminderTimes {
    static func changes(setting times: [LocalTime], on habit: TaskItem) -> [TaskEdit] {
        habit.due == nil ? [.reminderTimes(times)] : [.reminderTimes(times), .due(nil)]
    }
}
