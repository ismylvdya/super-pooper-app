import Foundation
import Observation

/// Permission states of the system sources, refreshed on demand.
struct SourceAccessState: Equatable {
    var calendars: SourceAccess = .notDetermined
    var reminders: SourceAccess = .notDetermined
    var notifications: SourceAccess = .notDetermined
}

/// What Calendar and Reminders hold for the app: the anchor events and the reminders around today, read from the
/// calendars and lists the settings name, and whether the app may read them and send notifications. Reads can overlap
/// (settings changed, Calendar changed, a sync); only the newest one is kept.
@MainActor
@Observable
final class SourcesController {
    private(set) var events: [CalendarEvent] = []
    private(set) var reminders: [ReminderItem] = []
    private(set) var access = SourceAccessState()
    @ObservationIgnored private let calendars: CalendarRepository
    @ObservationIgnored private let reminderStore: RemindersRepository
    @ObservationIgnored private let notifications: NotificationScheduling
    @ObservationIgnored private let config: AppConfig
    @ObservationIgnored private let settings: SettingsController
    @ObservationIgnored private let day: DayStateController
    /// Counts the reads; an older read that ends later is dropped.
    @ObservationIgnored private var generation = 0

    init(calendars: CalendarRepository, reminders: RemindersRepository, notifications: NotificationScheduling,
         config: AppConfig, settings: SettingsController, day: DayStateController) {
        self.calendars = calendars
        reminderStore = reminders
        self.notifications = notifications
        self.config = config
        self.settings = settings
        self.day = day
    }

    /// Without Calendar access or chosen calendars, a linked event cannot be looked up.
    var eventsKnown: Bool {
        calendars.access == .granted && !settings.settings.sources.anchorCalendarIDs.isEmpty
    }

    func availableCalendars() -> [SourceCollection] { calendars.calendars() }
    func availableReminderLists() -> [SourceCollection] { reminderStore.lists() }

    func refreshAccess() async {
        let notifications = await notifications.access()
        access = SourceAccessState(calendars: calendars.access, reminders: reminderStore.access, notifications: notifications)
    }

    /// Re-reads anchor events and reminders (cheap, no vault access): the events of the days links are looked up in, the
    /// reminders of the past days browsed on Today up to the notification horizon.
    func refresh() async {
        generation += 1
        let generation = generation
        let context = day.context()
        let calendar = day.calendar
        let rules = config.rules
        let sources = settings.settings.sources
        let boundary = settings.settings.day.boundary
        let from = context.today.adding(days: -rules.eventLinks.resolveDaysBefore).startDate(in: calendar)
        let to = context.today.adding(days: rules.eventLinks.resolveDaysAfter + 1).startDate(in: calendar)
        let events = await calendars.events(from: from, to: to, calendarIDs: sources.anchorCalendarIDs)
        var reminders: [ReminderItem] = []
        if config.flags.reminders {
            let until = context.today.adding(days: rules.notifications.horizonDays).startDate(in: calendar, offset: boundary)
            let from = context.today.adding(days: -rules.eventLinks.resolveDaysBefore).startDate(in: calendar, offset: boundary)
            reminders = await reminderStore.reminders(from: from, to: until, listIDs: sources.reminderListIDs)
        }
        guard generation == self.generation else { return }
        replaceItems(events: events, reminders: reminders)
    }

    func replaceItems(events: [CalendarEvent], reminders: [ReminderItem]) {
        self.events = events
        self.reminders = reminders
    }

    /// A reminder checked off (or back on) here shows so at once, before Reminders is read again.
    func showCompleted(_ completed: Bool, reminderID: String) {
        reminders = reminders.map { item in
            guard item.id == reminderID else { return item }
            var toggled = item
            toggled.isCompleted = completed
            return toggled
        }
    }

    /// An event deleted here leaves the timeline at once, before Calendar is read again.
    func showDeleted(_ event: CalendarEvent) {
        events = events.filter { $0.id != event.id }
    }
}
