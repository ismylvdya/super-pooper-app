import Foundation
@preconcurrency import UserNotifications

/// Keeps notifications pending about the end of the installed app's signature: one an hour through its last day, already
/// in place in case the app is not opened then. Their identifiers are outside the app's planned notifications, so their
/// sync leaves them alone.
struct SigningExpiryReminder: Sendable {
    let identifier: String
    let leadHours: Double
    let everyHours: Double
    let signature: AppSignatureReading
    let content: @Sendable (Date) -> (title: String, body: String)

    /// The check of the Shortcuts action: the warning right away when the signature runs out soon.
    func notifyIfSoon(now: Date) async {
        guard let expiration = signature.expiration(), SigningExpiry.isSoon(expiration: expiration, leadHours: leadHours, now: now) else { return }
        let text = content(expiration)
        let request = UNMutableNotificationContent()
        request.title = text.title
        request.body = text.body
        request.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier + "|now", content: request, trigger: nil))
    }

    func schedule(now: Date) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(identifier + "|at") }
        center.removePendingNotificationRequests(withIdentifiers: pending + [identifier])
        guard let expiration = signature.expiration() else { return }
        let text = content(expiration)
        let dates = SigningExpiry.reminderDates(expiration: expiration, leadHours: leadHours, everyHours: everyHours, now: now)
        for (index, date) in dates.enumerated() {
            let request = UNMutableNotificationContent()
            request.title = text.title
            request.body = text.body
            request.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSince(now), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: identifier + "|at\(index)", content: request, trigger: trigger))
        }
    }
}
