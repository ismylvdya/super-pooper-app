import Foundation

/// When a pending notification rings. A wall-clock time (a task or habit without a zone of its own) is the clock time
/// alone, so after a flight 09:00 still rings at 09:00; a moment (`isAbsolute`) carries its zone and rings at that
/// moment wherever the phone is.
enum NotificationTrigger {
    static func components(for notification: PlannedNotification, calendar: Calendar) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notification.fireDate)
        if notification.isAbsolute { components.timeZone = calendar.timeZone }
        return components
    }
}
