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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return WidgetDataSource(config: config,
                                settings: SettingsStore(store: store, defaults: config.defaultSettings).load(),
                                snapshot: SnapshotStore(store: store).load(),
                                calendar: calendar)
    }

    func context(at date: Date) -> DayContext {
        DayContext(now: date, calendar: calendar, boundary: settings.day.boundary, energyHour: settings.day.energyHour)
    }

    func plan(at date: Date) -> DayPlan {
        let context = context(at: date)
        guard let snapshot else { return .empty(today: context.today, now: date) }
        let state = snapshot.dayState.day == context.today ? snapshot.dayState : DayState(day: context.today)
        let inputs = DayInputs(tasks: snapshot.tasks, events: snapshot.events, reminders: snapshot.reminders,
                               skipped: Set(state.skipped), manualOrder: state.manualOrder)
        return DayBuilder(rules: config.rules.day, sortCriteria: config.sort.pool).build(inputs, context: context)
    }

    var habitNames: [String] {
        (snapshot?.tasks ?? []).filter(\.isRecurring).map(\.name).sorted()
    }

    func habit(named name: String?) -> TaskNote? {
        let habits = (snapshot?.tasks ?? []).filter(\.isRecurring)
        return habits.first { $0.name == name } ?? habits.sorted { $0.name < $1.name }.first
    }
}
