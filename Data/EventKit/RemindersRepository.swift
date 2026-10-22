import EventKit
import UIKit

/// Read-only access to "remember at X" reminders. The inbox list is never touched:
/// only lists chosen in settings are read.
protocol RemindersRepository: Sendable {
    var access: SourceAccess { get }
    func requestAccess() async -> Bool
    func lists() -> [SourceCollection]
    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem]
}

struct EventKitRemindersRepository: RemindersRepository {
    let eventKit: EventKitAccess
    let calendar: Calendar

    var access: SourceAccess { eventKit.access(for: .reminder) }

    func requestAccess() async -> Bool { await eventKit.requestAccess(for: .reminder) }

    func lists() -> [SourceCollection] {
        guard access == .granted else { return [] }
        return eventKit.store.calendars(for: .reminder)
            .map(\.sourceCollection)
            .sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }
    }

    func reminders(from start: Date, to end: Date, listIDs: [String]) async -> [ReminderItem] {
        guard access == .granted, !listIDs.isEmpty else { return [] }
        let lists = eventKit.store.calendars(for: .reminder).filter { listIDs.contains($0.calendarIdentifier) }
        guard !lists.isEmpty else { return [] }
        let predicate = eventKit.store.predicateForReminders(in: lists)
        let calendar = self.calendar
        let reminders: [ReminderItem] = await withCheckedContinuation { continuation in
            eventKit.store.fetchReminders(matching: predicate) { found in
                let items = (found ?? []).compactMap { reminder -> ReminderItem? in
                    guard let components = reminder.dueDateComponents, components.hour != nil,
                          let due = calendar.date(from: components), due >= start, due < end else { return nil }
                    return ReminderItem(id: reminder.calendarItemIdentifier, title: reminder.title ?? "", due: due,
                                        listID: reminder.calendar.calendarIdentifier, listTitle: reminder.calendar.title,
                                        colorHex: UIColor(cgColor: reminder.calendar.cgColor).hexString,
                                        isCompleted: reminder.isCompleted)
                }
                continuation.resume(returning: items)
            }
        }
        return reminders.sorted { $0.due < $1.due }
    }
}
