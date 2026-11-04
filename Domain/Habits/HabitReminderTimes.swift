import Foundation

/// A habit's reminder times. They take the place of an older-style time of day in `due`, which goes when they are set.
enum HabitReminderTimes {
    static func changes(setting times: [LocalTime], on habit: TaskItem) -> [TaskEdit] {
        let alarms = habit.alarms.following(times: habit.habitTimes, to: times)
        let edits: [TaskEdit] = alarms == habit.alarms ? [.reminderTimes(times)] : [.reminderTimes(times), .alarms(alarms)]
        return habit.due == nil ? edits : edits + [.due(nil)]
    }
}
