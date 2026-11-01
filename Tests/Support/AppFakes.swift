import Foundation
@preconcurrency import UserNotifications
@testable import SuperPooperApp

/// Notifications that remember the last plan and, in order, what reached the center. The first plan can be held at a
/// gate the test opens (a slow notification center).
actor RecordingNotifications: NotificationScheduling {
    private(set) var lastPlanned: [PlannedNotification] = []
    private(set) var calls = 0
    /// "sync", or "restore" and the identifier ("cancelled restore" when the restore's task was cancelled).
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
        log.append((Task.isCancelled ? "cancelled restore " : "restore ") + request.identifier)
    }

    func remove(shown identifier: String) async {
        log.append("remove " + identifier)
    }
}

/// Reminders of the asked lists; reading the "old" list waits at a gate the test opens.
struct ListedReminders: RemindersRepository {
    let oldList = AsyncGate()

    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [] }
    func setCompleted(_ completed: Bool, reminderID: String) throws {}
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }

    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] {
        if listIDs == ["old"] { await oldList.pass() }
        return listIDs.map { ReminderItem(id: $0, title: $0, due: start, listID: $0, listTitle: $0, colorHex: "#000000", isCompleted: false) }
    }
}

/// The preview's reminders, every one of them deleted in Reminders meanwhile: checking one off fails.
struct GoneReminders: RemindersRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [] }
    func setCompleted(_ completed: Bool, reminderID: String) throws { throw ReminderEditError.reminderNotFound }
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] { [] }
}

/// One reminder an hour after the end of the logical day.
struct EarlyReminder: RemindersRepository {
    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func lists() -> [SourceCollection] { [] }
    func setCompleted(_ completed: Bool, reminderID: String) throws {}
    func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }

    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] {
        let due = PreviewSamples.context.dayEnd.addingTimeInterval(3600)
        return [ReminderItem(id: "early", title: "Early", due: due, listID: "list", listTitle: "List", colorHex: "#000000", isCompleted: false)]
    }
}

/// Calendars with the test's events, whose store changes the test sends; counts the reads and records deletes.
final class FakeCalendars: CalendarRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<Void>.Continuation?
    private var stored: [CalendarEvent]
    private var readCount = 0
    private var deletedEvents: [CalendarEvent] = []

    init(events: [CalendarEvent] = []) {
        stored = events
    }

    var reads: Int { lock.withLock { readCount } }
    var deleted: [CalendarEvent] { lock.withLock { deletedEvents } }

    /// The store posts a change notice.
    func change() {
        _ = lock.withLock { continuation }?.yield()
    }

    var access: SourceAccess { .granted }
    func requestAccess() async -> Bool { true }
    func calendars() -> [SourceCollection] { [] }

    func events(from start: Date, to end: Date, calendarIDs: [String]) -> [CalendarEvent] {
        lock.withLock {
            readCount += 1
            return stored
        }
    }

    func delete(_ event: CalendarEvent) throws {
        try lock.withLock {
            guard let index = stored.firstIndex(of: event) else { throw CalendarEditError.eventNotFound }
            deletedEvents.append(stored.remove(at: index))
        }
    }

    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in lock.withLock { self.continuation = continuation } }
    }
}
