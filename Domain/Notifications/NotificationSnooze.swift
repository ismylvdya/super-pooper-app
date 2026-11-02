import Foundation

/// An event's or reminder's notification snoozed from its button: the same notification comes again at `until`. Nothing
/// about its item changes. It is told apart by its key and day (`PlannedNotification.key`, `day`), which stay the same when
/// the item is moved. A task's or habit's snooze moves its block instead (`NotificationSnoozing.moves`).
struct NotificationSnooze: Codable, Hashable, Sendable {
    let key: String
    let day: LocalDate
    let until: Date
}

/// Which snoozed notifications come again. A snooze lives its notification's logical day: it is planned while the
/// notification itself would stay in Notification Center (`NotificationPlanner.stillValidToday`: its item open on that
/// day) and only if it comes before that day ends; once the day is over it is forgotten.
enum NotificationSnoozing {
    /// The notifications that come again, each at its snooze time; `valid` is today's notifications.
    static func notifications(_ snoozes: [NotificationSnooze], valid: [PlannedNotification],
                              context: DayContext) -> [PlannedNotification] {
        snoozes.compactMap { snooze in
            guard snooze.day == context.today, snooze.until < context.dayEnd,
                  let original = valid.first(where: { $0.key == snooze.key && $0.day == snooze.day }) else { return nil }
            return original.snoozed(until: snooze.until)
        }
    }

    /// The snoozes after `snooze`: it replaces an earlier snooze of the same notification; those of days that are over go.
    static func adding(_ snooze: NotificationSnooze, to snoozes: [NotificationSnooze], today: LocalDate) -> [NotificationSnooze] {
        current(snoozes, today: today).filter { $0.key != snooze.key || $0.day != snooze.day } + [snooze]
    }

    /// Snooze on a task's or habit's notification moves its block on today's timeline to the moment the notification
    /// comes again (`until`), for today only, so the timeline and the notification tell the same time; the notification
    /// follows the block (`NotificationPlanner`). Nil for an event or a reminder (only their notification comes again), a
    /// notification of another day, or a moment past the end of today.
    static func moves(snoozing notification: PlannedNotification, of task: TaskItem, until: Date, today: TodayTimes,
                      context: DayContext) -> [TimeMove]? {
        guard [.habit, .task].contains(notification.kind), let slot = notification.slot, notification.day == context.today,
              until < context.dayEnd else { return nil }
        return today.moving(task, slot: slot, to: LocalTime(until, in: context.calendar))
    }

    /// The snoozes still of today or later.
    static func current(_ snoozes: [NotificationSnooze], today: LocalDate) -> [NotificationSnooze] {
        snoozes.filter { !StaleNotifications.isOver($0.day, today: today) }
    }
}
