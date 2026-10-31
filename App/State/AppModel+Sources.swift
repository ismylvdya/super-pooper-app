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

    /// Checks a reminder off (or back on) in Reminders. It shows at once; the reminders are read back with the store's
    /// own notice of the edit, in one go (`sourcesDidChange`).
    func toggleReminder(_ reminder: ReminderItem) async {
        do {
            try await services.reminders.setCompleted(!reminder.isCompleted, reminderID: reminder.id)
            setSources(events: events, reminders: reminders.map { item in
                guard item.id == reminder.id else { return item }
                var toggled = item
                toggled.isCompleted = !reminder.isCompleted
                return toggled
            })
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        sourcesDidChange()
    }

    /// The event of a notification: the occurrence of the alert's day (`EventOccurrence`), read again if it is not
    /// known yet. Without one nothing is deleted: another occurrence of a repeating event must never go instead.
    func deleteEvent(identifier: String, start: Date) async {
        var occurrence = EventOccurrence.find(identifier: identifier, start: start, in: events, context: context())
        if occurrence == nil {
            await refreshCalendarSources()
            occurrence = EventOccurrence.find(identifier: identifier, start: start, in: events, context: context())
        }
        guard let occurrence else {
            appEvents.send(.failure(.eventNotFound))
            return
        }
        await deleteEvent(occurrence)
    }

    /// The event leaves the timeline at once; the calendars are read back with the store's own notice of the edit.
    func deleteEvent(_ event: CalendarEvent) async {
        do {
            try await services.calendars.delete(event)
            setSources(events: events.filter { $0.id != event.id }, reminders: reminders)
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        sourcesDidChange()
    }
}

extension AppModel {
    /// A vault folder is chosen (it may still be loading).
    var hasVault: Bool { services.vault.hasVault }

    func selectVault(_ url: URL) async {
        SyncLog.logger.info("vault selected: \(url.path, privacy: .public)")
        do {
            try services.vault.select(url)
            await sync(announce: true)
            if chosenFolder.isWholeVault { appEvents.send(.wholeVaultChosen) }
        } catch {
            SyncLog.logger.error("vault selection failed: \(String(describing: error), privacy: .public)")
            appEvents.send(.failure(AppFailure(error)))
        }
    }
}
