import Foundation
@preconcurrency import UserNotifications
@testable import SuperPooperApp

/// Notifications that remember the last plan and, in order, what reached the center. The first plan can be held at a
/// gate the test opens (a slow notification center).
actor RecordingNotifications: NotificationScheduling {
    private(set) var lastPlanned: [PlannedNotification] = []
    private(set) var calls = 0
    /// "sync", or "restore" and the identifier.
    private(set) var log: [String] = []
    private let firstSync: AsyncGate?

    init(firstSync: AsyncGate? = nil) {
        self.firstSync = firstSync
    }

    nonisolated func access() async -> SourceAccess { .granted }
    nonisolated func requestAccess() async -> Bool { true }
    nonisolated func registerCategories(_ registry: ActionRegistry, habitActionsEnabled: Bool) {}

    func sync(planned: [PlannedNotification], stillValid: [PlannedNotification], now immediate: [PlannedNotification]) async {
        calls += 1
        // The real center does not stop when the task is cancelled: the gate ignores cancellation too.
        if calls == 1, let firstSync { await firstSync.pass() }
        lastPlanned = planned
        log.append("sync")
    }

    func removeAll() async { lastPlanned = [] }

    func restore(_ request: UNNotificationRequest) async {
        log.append("restore " + request.identifier)
    }
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
