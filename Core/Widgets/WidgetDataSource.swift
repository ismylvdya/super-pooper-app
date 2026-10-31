import Foundation

/// Everything a widget needs, read from the App Group: configs, user settings and the snapshot
/// the app writes on every sync. The day is rebuilt with the same domain code as in the app.
struct WidgetDataSource: Sendable {
    let config: AppConfig
    let settings: AppSettings
    let snapshot: WidgetSnapshot?
    let calendar: Calendar

    static func load(bundle: Bundle = .main) -> WidgetDataSource? {
        guard let config = try? AppConfig.load(bundle: bundle) else { return nil }
        let store = JSONFileStore(directory: AppGroupContainer.directory(bundle: bundle))
        // A widget process can outlive a time zone change: the system zone is read afresh for every timeline.
        NSTimeZone.resetSystemTimeZone()
        let calendar = AppCalendar.make()
        // Everything in the widget reads `today.arrangement`, so it gets the widget's own one there.
        var settings = SettingsStore(store: store, defaults: config.defaultSettings).load()
        settings.today.arrangement = settings.today.widgetArrangement.forWidget
        return WidgetDataSource(config: config,
                                settings: settings,
                                snapshot: SnapshotStore(store: store).load(),
                                calendar: calendar)
    }

    func context(at date: Date) -> DayContext {
        DayContext(now: date, calendar: calendar, boundary: settings.day.boundary, energyHour: settings.day.energyHour)
    }

    func plan(at date: Date) -> DayPlan {
        let context = context(at: date)
        guard let snapshot else { return .empty(today: context.today, now: date) }
        return DayPlanning.plan(config: config, settings: settings, tasks: snapshot.tasks, events: snapshot.events, reminders: snapshot.reminders,
                                dayState: snapshot.dayState, context: context, eventsKnown: snapshot.eventsKnown ?? false)
    }

    /// Active habits in the user's list order.
    var habits: [TaskItem] {
        HabitOrder.sorted((snapshot?.tasks ?? []).filter { $0.isHabit && !$0.isArchived }, order: settings.habits.order)
    }

    var habitNames: [String] { habits.map(\.name) }

    /// The chosen habit; the first one until a habit is chosen. A chosen habit that is gone (renamed, deleted)
    /// gives nil, so the widget asks to choose again instead of showing and marking another habit.
    func habit(named name: String?) -> TaskItem? {
        guard let name else { return habits.first }
        return habits.first { $0.name.isSameNoteName(as: name) }
    }
}
