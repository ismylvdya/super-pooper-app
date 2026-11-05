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

    /// Snooze on a notification: the one shown (`identifier`) goes, the same comes again later; a task takes that time.
    func snoozeNotification(key: String, day: LocalDate, shown identifier: String) async {
        let commands = parts.dayCommands
        await parts.derived.snooze(key: key, day: day, shown: identifier) { name, moment in
            await commands.schedule(name, slot: nil, at: moment)
        }
    }

    func requestAlarmAccess() async -> Bool { await parts.derived.requestAlarmAccess() }

    /// The sounds an alarm may have: the app's and, as far as they can be read, the phone's.
    var alarmSounds: [RulesConfig.Alarms.Sound] { SystemAlarmSounds.all(config.rules.alarms) }

    /// A sound's name as the menus show it.
    func alarmSoundTitle(_ id: String) -> String {
        alarmSounds.first { $0.id == id }.map { L10n.string($0.title) } ?? id
    }

    /// The user's own alarm sounds.
    var customAlarmSounds: [RulesConfig.Alarms.Sound] { SystemAlarmSounds.custom() }
    func addAlarmSound(from file: URL) async -> String? { await SystemAlarmSounds.addCustom(from: file, rules: config.rules.alarms) }
    func removeAlarmSound(_ id: String) { SystemAlarmSounds.removeCustom(id) }

    /// A phone's tone chosen for an alarm is made ready for it.
    func prepareAlarmSound(_ id: String?) async { await SystemAlarmSounds.install(id, rules: config.rules.alarms) }

    /// Dismiss alert on an event alert: the one shown (`identifier`) goes and does not come back; the event stays.
    func dismissNotification(shown identifier: String) async { await parts.derived.dismiss(shown: identifier) }

    /// Background work waits for these before the app is suspended.
    func waitForNotifications() async { await parts.derived.waitForNotifications() }
    func waitForSourceRefresh() async { await parts.sourceCommands.waitForRefresh() }
}
