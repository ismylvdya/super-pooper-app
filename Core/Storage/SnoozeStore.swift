import Foundation

/// The notifications snoozed from their button (`NotificationSnooze`), kept next to the notification plan so a snooze
/// survives planning again, a sync and a relaunch.
struct SnoozeStore: Sendable {
    static let fileName = "snoozed-notifications.json"

    let store: JSONFileStore

    func load() -> [NotificationSnooze] { store.read([NotificationSnooze].self, from: Self.fileName) ?? [] }

    func save(_ snoozes: [NotificationSnooze]) throws { try store.write(snoozes, to: Self.fileName) }
}
