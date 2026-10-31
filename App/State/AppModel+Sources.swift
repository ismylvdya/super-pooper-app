import Foundation
@preconcurrency import UserNotifications

/// Calendar and Reminders, and the notifications: access, the items, edits there, and the waits background work needs.
extension AppModel {
    /// Without Calendar access or chosen calendars, a linked event cannot be looked up.
    var eventsKnown: Bool { parts.sources.eventsKnown }
    func availableCalendars() -> [SourceCollection] { parts.sources.availableCalendars() }
    func availableReminderLists() -> [SourceCollection] { parts.sources.availableReminderLists() }

    func refreshAccess() async { await parts.sources.refreshAccess() }
    func requestCalendarAccess() async { await parts.sourceCommands.requestCalendarAccess() }
    func requestRemindersAccess() async { await parts.sourceCommands.requestRemindersAccess() }
    func requestNotificationAccess() async { await parts.sourceCommands.requestNotificationAccess() }

    func completeReminder(id: String) async { await parts.sourceCommands.completeReminder(id: id) }
    func toggleReminder(_ reminder: ReminderItem) async { await parts.sourceCommands.toggleReminder(reminder) }
    func deleteEvent(_ event: CalendarEvent) async { await parts.sourceCommands.deleteEvent(event) }
    func deleteEvent(identifier: String, start: Date) async {
        await parts.sourceCommands.deleteEvent(identifier: identifier, start: start)
    }

    /// Edits made in Calendar and Reminders while the app runs reach the timeline and the notifications.
    func observeSourceChanges() { parts.sourceCommands.observeChanges() }

    /// A notification swiped away or tapped comes back silently while its day lasts.
    func restoreNotification(_ request: UNNotificationRequest) async { await parts.derived.restore(request) }

    /// Background work waits for these before the app is suspended.
    func waitForNotifications() async { await parts.derived.waitForNotifications() }
    func waitForSourceRefresh() async { await parts.sourceCommands.waitForRefresh() }
}
