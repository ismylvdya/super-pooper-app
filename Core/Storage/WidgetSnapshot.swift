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
    /// The app could read the chosen calendars, so a linked event that is missing is a problem; nil in a snapshot of an
    /// older version (taken as unknown).
    let eventsKnown: Bool?
}

struct SnapshotStore: Sendable {
    static let fileName = "widget-snapshot.json"

    let store: JSONFileStore

    func load() -> WidgetSnapshot? { store.read(WidgetSnapshot.self, from: Self.fileName) }

    func save(_ snapshot: WidgetSnapshot) throws { try store.write(snapshot, to: Self.fileName) }
}
