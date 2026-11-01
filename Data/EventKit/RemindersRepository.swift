import EventKit
import UIKit

/// "Remember at X" reminders: read, and checked off from the timeline. The inbox list is never
/// touched: only lists chosen in settings are used.
protocol RemindersRepository: Sendable {
    var access: SourceAccess { get }
    func requestAccess() async -> Bool
    func lists() -> [SourceCollection]
    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem]
    /// Throws `ReminderEditError.reminderNotFound` when the reminder is gone (deleted elsewhere, its list removed).
    func setCompleted(_ completed: Bool, reminderID: String) async throws
    /// Reminders changed, here or elsewhere; a burst of changes comes as several signals.
    func changes() -> AsyncStream<Void>
}

enum ReminderEditError: Error, Equatable {
    case reminderNotFound
}

struct EventKitRemindersRepository: RemindersRepository {
    let eventKit: EventKitAccess
    let calendar: CalendarSource

    var access: SourceAccess { eventKit.access(for: .reminder) }

    func requestAccess() async -> Bool { await eventKit.requestAccess(for: .reminder) }

    func changes() -> AsyncStream<Void> { eventKit.changes() }

    func setCompleted(_ completed: Bool, reminderID: String) async throws {
        try await eventKit.write { store in
            guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
                throw ReminderEditError.reminderNotFound
            }
            reminder.isCompleted = completed
            try store.save(reminder, commit: true)
        }
    }

    func lists() -> [SourceCollection] {
        guard access == .granted else { return [] }
        return eventKit.store.calendars(for: .reminder)
            .map(\.sourceCollection)
            .sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }
    }

    /// Open reminders due in the range and the ones checked off in it, not every reminder of the lists: a list keeps
    /// all its completed reminders for years.
    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] {
        guard access == .granted, !listIDs.isEmpty else { return [] }
        let store = eventKit.store
        let lists = store.calendars(for: .reminder).filter { listIDs.contains($0.calendarIdentifier) }
        guard !lists.isEmpty else { return [] }
        let open = await items(matching: store.predicateForIncompleteReminders(withDueDateStarting: start, ending: end, calendars: lists),
                               from: start, to: end)
        let done = await items(matching: store.predicateForCompletedReminders(withCompletionDateStarting: start, ending: end,
                                                                               calendars: lists),
                               from: start, to: end)
        return (open + done).sorted { $0.due < $1.due }
    }

    /// Reminders with a due time in the range (EventKit calls back off the main thread).
    private func items(matching predicate: NSPredicate, from start: Date, to end: Date) async -> [ReminderItem] {
        let calendar = self.calendar.current
        return await withCheckedContinuation { continuation in
            eventKit.store.fetchReminders(matching: predicate) { found in
                continuation.resume(returning: (found ?? []).compactMap { reminder -> ReminderItem? in
                    guard let components = reminder.dueDateComponents, components.hour != nil,
                          let due = calendar.date(from: components), due >= start, due < end else { return nil }
                    return ReminderItem(id: reminder.calendarItemIdentifier, title: reminder.title ?? "", due: due,
                                        listID: reminder.calendar.calendarIdentifier, listTitle: reminder.calendar.title,
                                        colorHex: UIColor(cgColor: reminder.calendar.cgColor).hexString,
                                        isCompleted: reminder.isCompleted)
                })
            }
        }
    }
}
