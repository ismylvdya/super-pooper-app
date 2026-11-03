import Foundation

/// Where a tap on a notification leads: an event alert opens Apple Calendar on the event's day and hour, a reminder its
/// list in Apple Reminders (through the reminder: a link to the list itself is ignored), a habit or a task its page.
enum NotificationTapTarget {
    static func url(for info: [AnyHashable: Any], links: RulesConfig.EventLinks) -> URL? {
        switch (info[NotificationPayload.kindKey] as? String).flatMap(PlannedNotification.Kind.init(rawValue:)) {
        case .event:
            guard let start = info[NotificationPayload.eventStartKey] as? Double, start > 0 else { return nil }
            return links.calendarURL(at: Date(timeIntervalSince1970: start))
        case .reminder:
            guard let reminder = info[NotificationPayload.reminderKey] as? String, !reminder.isEmpty else { return nil }
            return links.reminderURL(id: reminder)
        case .habit:
            return (info[NotificationPayload.taskKey] as? String).flatMap(DeepLink.habit)
        case .task:
            return (info[NotificationPayload.taskKey] as? String).flatMap(DeepLink.task)
        case nil:
            return nil
        }
    }
}
