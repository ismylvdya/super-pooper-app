import Foundation
@preconcurrency import UserNotifications

/// What a response to a delivered notification asks for.
enum NotificationResponse: Equatable {
    /// Swiped away or tapped: the item stays in the day and the notification comes back silently until it is marked. A
    /// tap on an event alert opens Calendar on its day, on a reminder its list in Reminders.
    case putBack(opening: URL?)
    case completeReminder(id: String)
    /// Delete event on an event alert: the occurrence that alert belongs to.
    case deleteEvent(identifier: String, start: Date)
    /// Snooze on any notification: the notification of this key and day comes again later.
    case snooze(key: String, day: LocalDate)
    /// A button on a task's or habit's notification, for the day the notification belongs to.
    case perform(ActionID, taskName: String, day: LocalDate?)
    case ignore
}

/// Reads a notification response from the action the user chose and the notification's payload (`NotificationPayload`).
struct NotificationResponseRouter {
    let links: RulesConfig.EventLinks

    func route(action: String, info: [AnyHashable: Any]) -> NotificationResponse {
        if action == UNNotificationDismissActionIdentifier || action == UNNotificationDefaultActionIdentifier {
            let opens = action == UNNotificationDefaultActionIdentifier ? NotificationTapTarget.url(for: info, links: links) : nil
            return .putBack(opening: opens)
        }
        let day = (info[NotificationPayload.dayKey] as? String).flatMap(LocalDate.init(isoString:))
        if action == ActionID.snooze.rawValue {
            guard let key = info[NotificationPayload.keyKey] as? String, !key.isEmpty, let day else { return .ignore }
            return .snooze(key: key, day: day)
        }
        if (info[NotificationPayload.kindKey] as? String) == PlannedNotification.Kind.reminder.rawValue,
           let reminderID = info[NotificationPayload.reminderKey] as? String, !reminderID.isEmpty,
           action == ActionID.done.rawValue {
            return .completeReminder(id: reminderID)
        }
        if action == ActionID.deleteEvent.rawValue,
           let eventID = info[NotificationPayload.eventKey] as? String, !eventID.isEmpty,
           let start = info[NotificationPayload.eventStartKey] as? Double {
            return .deleteEvent(identifier: eventID, start: Date(timeIntervalSince1970: start))
        }
        guard let chosen = ActionID(rawValue: action),
              let taskName = info[NotificationPayload.taskKey] as? String, !taskName.isEmpty else { return .ignore }
        return .perform(chosen, taskName: taskName, day: day)
    }
}
