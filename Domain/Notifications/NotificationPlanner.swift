import Foundation

/// A local notification the app wants to have pending.
struct PlannedNotification: Hashable, Sendable {
    enum Kind: String, Sendable {
        case habit
        case task
        case reminder
    }

    let id: String
    let kind: Kind
    let title: String
    let fireDate: Date
    /// The task the notification acts on (nil for reminders).
    let taskName: String?
    /// The day the notification belongs to (habit marks are written for this day).
    let day: LocalDate
}

/// Decides which notifications should be pending: timed habits, timed tasks of this week and timed reminders.
/// Anything whose time has passed is never planned (better skipped than late).
struct NotificationPlanner: Sendable {
    let horizonDays: Int
    let limit: Int

    /// Upcoming notifications, nearest first, at most `limit`.
    func plan(tasks: [TaskNote], reminders: [ReminderItem], skipped: Set<String>, context: DayContext) -> [PlannedNotification] {
        Array(all(tasks: tasks, reminders: reminders, skipped: skipped, context: context)
            .filter { $0.fireDate > context.now }
            .prefix(limit))
    }

    /// Today's notifications regardless of time: a delivered one stays in Notification Center
    /// only while it is still in this list.
    func stillValidToday(tasks: [TaskNote], reminders: [ReminderItem], skipped: Set<String>, context: DayContext) -> [PlannedNotification] {
        all(tasks: tasks, reminders: reminders, skipped: skipped, context: context).filter { $0.day == context.today }
    }

    private func all(tasks: [TaskNote], reminders: [ReminderItem], skipped: Set<String>, context: DayContext) -> [PlannedNotification] {
        let occurrence = TaskOccurrence(calendar: context.calendar)
        var result: [PlannedNotification] = []

        for task in tasks {
            guard let due = task.due, let time = due.time else { continue }
            if task.isRecurring {
                let instances = HabitInstances(task: task)
                for offset in 0..<horizonDays {
                    let day = context.today.adding(days: offset)
                    guard occurrence.occurs(task, on: day), instances.mark(on: day) == nil else { continue }
                    if day == context.today, skipped.contains(task.name) { continue }
                    result.append(PlannedNotification(id: "habit|\(task.name)|\(day.isoString)", kind: .habit,
                                                      title: task.name, fireDate: context.date(day, time),
                                                      taskName: task.name, day: day))
                }
            } else if task.status == .thisWeek {
                result.append(PlannedNotification(id: "task|\(task.name)", kind: .task, title: task.name,
                                                  fireDate: context.date(due.day, time), taskName: task.name, day: due.day))
            }
        }

        for reminder in reminders where !reminder.isCompleted {
            result.append(PlannedNotification(id: "reminder|\(reminder.id)|\(reminder.due.timeIntervalSince1970)", kind: .reminder,
                                              title: reminder.title, fireDate: reminder.due, taskName: nil,
                                              day: LocalDate(reminder.due, in: context.calendar)))
        }

        return result.sorted { $0.fireDate < $1.fireDate }
    }
}
