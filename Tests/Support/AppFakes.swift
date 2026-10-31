import Foundation
@preconcurrency import UserNotifications
@testable import SuperPooperApp

/// Notifications that remember the last plan; the first plan takes a while to arrive (a slow notification center).
actor RecordingNotifications: NotificationScheduling {
    private(set) var lastPlanned: [PlannedNotification] = []
    private(set) var calls = 0

    nonisolated func access() async -> SourceAccess { .granted }
    nonisolated func requestAccess() async -> Bool { true }
    nonisolated func registerCategories(_ registry: ActionRegistry, habitActionsEnabled: Bool) {}

    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification], now immediate: [PlannedNotification]) async {
        calls += 1
        // The real center does not stop when the task is cancelled: a wait that ignores cancellation.
        if calls == 1 {
            await withCheckedContinuation { done in DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { done.resume() } }
        }
        lastPlanned = planned
    }

    func removeAll() async { lastPlanned = [] }
    nonisolated func restore(_ notification: UNNotification) async {}
}

/// Reminders of the asked lists; the "old" list takes a while to read.
struct ListedReminders: RemindersRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [] }
    func setCompleted(_ completed: Bool, reminderID: String) throws {}

    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] {
        if listIDs == ["old"] {
            await withCheckedContinuation { done in DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { done.resume() } }
        }
        return listIDs.map { ReminderItem(id: $0, title: $0, due: start, listID: $0, listTitle: $0, colorHex: "#000000", isCompleted: false) }
    }
}

/// One reminder an hour after the end of the logical day.
struct EarlyReminder: RemindersRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [] }
    func setCompleted(_ completed: Bool, reminderID: String) throws {}

    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] {
        let due = PreviewSamples.context.dayEnd.addingTimeInterval(3600)
        return [ReminderItem(id: "early", title: "Early", due: due, listID: "list", listTitle: "List", colorHex: "#000000", isCompleted: false)]
    }
}
