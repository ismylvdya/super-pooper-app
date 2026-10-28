import Foundation
@preconcurrency import UserNotifications

/// Reads when the installed app's signature runs out and keeps one notification about it pending. Its identifier
/// is outside the app's planned notifications, so their sync leaves it alone.
struct SigningExpiryReminder: Sendable {
    let identifier: String
    let leadHours: Double
    let content: @Sendable (Date) -> (title: String, body: String)

    /// The expiration of the provisioning profile inside the app (none in the simulator or an App Store build).
    static func expiration(in bundle: Bundle = .main) -> Date? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"), let end = text.range(of: "</plist>"),
              let plist = text[start.lowerBound..<end.upperBound].data(using: .isoLatin1),
              let object = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any]
        else { return nil }
        return object["ExpirationDate"] as? Date
    }

    /// The check of the Shortcuts action: the warning right away when the signature runs out soon.
    func notifyIfSoon(now: Date, expiration: Date? = Self.expiration()) async {
        guard let expiration, SigningExpiry.isSoon(expiration: expiration, leadHours: leadHours, now: now) else { return }
        let text = content(expiration)
        let request = UNMutableNotificationContent()
        request.title = text.title
        request.body = text.body
        request.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier + "|now", content: request, trigger: nil))
    }

    func schedule(now: Date, expiration: Date? = Self.expiration()) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let expiration, let date = SigningExpiry.warningDate(expiration: expiration, leadHours: leadHours, now: now) else { return }
        let text = content(expiration)
        let request = UNMutableNotificationContent()
        request.title = text.title
        request.body = text.body
        request.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSince(now), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: request, trigger: trigger))
    }
}
