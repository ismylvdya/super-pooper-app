import Foundation

/// The data the app hands to its widgets: widgets cannot reliably read iCloud files, so every
/// sync writes this snapshot to the App Group and widgets rebuild the day from it with the same
/// domain code as the app.
struct WidgetSnapshot: Codable, Sendable {
    let generatedAt: Date
    let tasks: [TaskNote]
    let events: [CalendarEvent]
    let reminders: [ReminderItem]
    let dayState: DayState
}

struct SnapshotStore: Sendable {
    static let fileName = "widget-snapshot.json"

    let store: JSONFileStore

    func load() -> WidgetSnapshot? { store.read(WidgetSnapshot.self, from: Self.fileName) }

    func save(_ snapshot: WidgetSnapshot) throws { try store.write(snapshot, to: Self.fileName) }
}
