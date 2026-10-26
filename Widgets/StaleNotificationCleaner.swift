@preconcurrency import UserNotifications

/// Widgets reload when the logical day ends, also while the app is closed: then they clear the app's notifications of
/// the day that is over. iOS cannot schedule the removal of a delivered notification, and the app itself only gets to
/// run when it is opened or refreshed in the background.
enum StaleNotificationCleaner {
    static func clear(today: LocalDate) async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
            .map(\.request)
            .filter { $0.identifier.hasPrefix(NotificationPayload.prefix) }
            .map { (identifier: $0.identifier, day: $0.content.userInfo[NotificationPayload.dayKey] as? String) }
        let stale = StaleNotifications.identifiers(delivered, today: today)
        if !stale.isEmpty { center.removeDeliveredNotifications(withIdentifiers: stale) }
    }
}
