import Foundation

/// Everything a widget needs, read from the App Group: configs, user settings and the snapshot
/// the app writes on every sync. The day is rebuilt with the same domain code as in the app.
struct WidgetDataSource: Sendable {
    let config: AppConfig
    let settings: AppSettings
    let snapshot: WidgetSnapshot?
    let calendar: Calendar
    /// The days' pool sections the app keeps in the App Group.
    var sections: [DaySections] = []

    static func load(bundle: Bundle = .main) -> WidgetDataSource? {
        guard let config = try? AppConfig.load(bundle: bundle) else { return nil }
        let store = JSONFileStore(directory: AppGroupContainer.directory(bundle: bundle))
        // A widget process can outlive a time zone change: the system zone is read afresh for every timeline.
        NSTimeZone.resetSystemTimeZone()
        let calendar = AppCalendar.make()
        return WidgetDataSource(config: config,
                                settings: SettingsStore(store: store, defaults: config.defaultSettings).load(),
                                snapshot: SnapshotStore(store: store).load(),
                                calendar: calendar,
                                sections: JSONDaySectionStore(store: store).snapshots())
    }

    /// The Today widget's own arrangement, independent from the app's; a widget has no pages.
    var arrangement: AppSettings.TodayArrangement { settings.today.widgetArrangement.forWidget }

    /// The Today widget's layout of the pool and the timeline (`layouts/today-*.layout.json`).
    var widgetLayout: ScreenLayout { config.todayLayout(for: arrangement) }

    func context(at date: Date) -> DayContext {
        DayContext(now: date, calendar: calendar, boundary: settings.day.boundary, energyHour: settings.day.energyHour)
    }

    func plan(at date: Date) -> DayPlan {
        let context = context(at: date)
        guard let snapshot else { return .empty(today: context.today, now: date) }
        return DayPlanning.plan(config: config, settings: settings, tasks: snapshot.tasks, events: snapshot.events, reminders: snapshot.reminders,
                                dayState: snapshot.dayState, sections: sections.first { $0.day == context.today }, context: context,
                                eventsKnown: snapshot.eventsKnown ?? false)
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
