import Foundation

/// Permission states of the system sources, refreshed on demand.
struct SourceAccessState: Equatable {
    var calendars: SourceAccess = .notDetermined
    var reminders: SourceAccess = .notDetermined
    var notifications: SourceAccess = .notDetermined
}

extension AppModel {
    func refreshAccess() async {
        let notifications = await services.notifications.access()
        access = SourceAccessState(calendars: services.calendars.access, reminders: services.reminders.access,
                                   notifications: notifications)
    }

    func requestCalendarAccess() async {
        _ = await services.calendars.requestAccess()
        await refreshAccess()
        await refreshCalendarSources()
    }

    func requestRemindersAccess() async {
        _ = await services.reminders.requestAccess()
        await refreshAccess()
        await refreshCalendarSources()
    }

    func requestNotificationAccess() async {
        _ = await services.notifications.requestAccess()
        await refreshAccess()
        await publishDerivedState()
    }

    func availableCalendars() -> [SourceCollection] { services.calendars.calendars() }
    func availableReminderLists() -> [SourceCollection] { services.reminders.lists() }
    var vaultName: String? { services.vault.displayName }

    /// Completes a reminder by id (the "Complete" button of its notification).
    func completeReminder(id: String) async {
        guard let reminder = reminders.first(where: { $0.id == id }) else { return }
        guard !reminder.isCompleted else { return }
        await toggleReminder(reminder)
    }

    /// Checks a reminder off (or back on) in Reminders, then refreshes everything that shows it.
    func toggleReminder(_ reminder: ReminderItem) async {
        do {
            try services.reminders.setCompleted(!reminder.isCompleted, reminderID: reminder.id)
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
        await refreshCalendarSources()
        await publishDerivedState()
    }

    func deleteEvent(_ event: CalendarEvent) async {
        do {
            try services.calendars.delete(event)
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
        await refreshCalendarSources()
        await publishDerivedState()
    }
}
