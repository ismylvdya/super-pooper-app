import Foundation

/// What the user does to Calendar and Reminders from the app (asks for access, checks a reminder off, deletes an event),
/// and the edits made there, elsewhere or by the app, reaching the timeline and the notifications while the app runs. A
/// burst of store changes (an iCloud sync of many events, one edit that posts several notices) is read once, after the
/// store has been quiet for `timeline.externalChangeDelaySeconds`.
@MainActor
final class SourceCommands {
    private let sources: SourcesController
    private let calendars: CalendarRepository
    private let reminders: RemindersRepository
    private let notifications: NotificationScheduling
    private let day: DayStateController
    private let derived: DerivedStatePublisher
    private let appEvents: AppEventSink
    private let delay: Delay
    private let quietSeconds: Double
    /// The read waiting for a burst of changes to end, and the loops that hear the changes.
    private var refreshAfterChange: Task<Void, Never>?
    private var observers: [Task<Void, Never>] = []

    init(sources: SourcesController, services: AppServices, day: DayStateController, derived: DerivedStatePublisher,
         appEvents: AppEventSink, delay: Delay, quietSeconds: Double) {
        self.sources = sources
        calendars = services.calendars
        reminders = services.reminders
        notifications = services.notifications
        self.day = day
        self.derived = derived
        self.appEvents = appEvents
        self.delay = delay
        self.quietSeconds = quietSeconds
    }

    func requestCalendarAccess() async {
        _ = await calendars.requestAccess()
        await sources.refreshAccess()
        await sources.refresh()
    }

    func requestRemindersAccess() async {
        _ = await reminders.requestAccess()
        await sources.refreshAccess()
        await sources.refresh()
    }

    func requestNotificationAccess() async {
        _ = await notifications.requestAccess()
        await sources.refreshAccess()
        await derived.publish()
    }

    /// Completes a reminder by id (the "Complete" button of its notification); one already done stays so.
    func completeReminder(id: String) async {
        guard let reminder = sources.reminders.first(where: { $0.id == id }), !reminder.isCompleted else { return }
        await toggleReminder(reminder)
    }

    /// Checks a reminder off (or back on) in Reminders. It shows at once; the reminders are read back with the store's
    /// own notice of the edit, in one go.
    func toggleReminder(_ reminder: ReminderItem) async {
        do {
            try await reminders.setCompleted(!reminder.isCompleted, reminderID: reminder.id)
            sources.showCompleted(!reminder.isCompleted, reminderID: reminder.id)
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        sourcesDidChange()
    }

    /// The event of a notification: the occurrence of the alert's day (`EventOccurrence`), read again if it is not known
    /// yet. Without one nothing is deleted: another occurrence of a repeating event must never go instead.
    func deleteEvent(identifier: String, start: Date) async {
        var occurrence = EventOccurrence.find(identifier: identifier, start: start, in: sources.events, context: day.context())
        if occurrence == nil {
            await sources.refresh()
            occurrence = EventOccurrence.find(identifier: identifier, start: start, in: sources.events, context: day.context())
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
            try await calendars.delete(event)
            sources.showDeleted(event)
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        sourcesDidChange()
    }

    func observeChanges() {
        guard observers.isEmpty else { return }
        observers = [calendars.changes(), reminders.changes()].map { changes in
            Task { [weak self] in
                for await _ in changes { self?.sourcesDidChange() }
            }
        }
    }

    /// A notification action run in the background waits for the read it caused before the app is suspended.
    func waitForRefresh() async {
        // A notice that came in meanwhile started the wait again.
        while let refresh = refreshAfterChange {
            await refresh.value
            if refreshAfterChange == refresh { break }
        }
        await derived.waitForNotifications()
    }

    private func sourcesDidChange() {
        refreshAfterChange?.cancel()
        refreshAfterChange = Task {
            try? await delay.wait(quietSeconds)
            guard !Task.isCancelled else { return }
            await sources.refresh()
            await derived.publish()
        }
    }
}
