import Foundation
@preconcurrency import UserNotifications

/// Keeps one notification pending about the end of the installed app's signature. Its identifier is outside the
/// app's planned notifications, so their sync leaves it alone.
struct SigningExpiryReminder: Sendable {
    let identifier: String
    let leadHours: Double
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
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let expiration = signature.expiration(), let date = SigningExpiry.warningDate(expiration: expiration, leadHours: leadHours, now: now) else { return }
        let text = content(expiration)
        let request = UNMutableNotificationContent()
        request.title = text.title
        request.body = text.body
        request.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSince(now), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: request, trigger: trigger))
    }
}
