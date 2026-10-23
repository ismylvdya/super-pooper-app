import Foundation

/// User settings shared by the app and the widgets.
struct SettingsStore: Sendable {
    static let fileName = "settings.json"

    let store: JSONFileStore
    let defaults: Data

    /// Stored values over defaults; a broken file falls back to defaults.
    func load() -> AppSettings {
        let merged = store.readData(Self.fileName).flatMap { try? JSONMerge.merge(base: defaults, overlay: $0) } ?? defaults
        if let settings = try? JSONDecoder.store.decode(AppSettings.self, from: merged) { return settings }
        return (try? JSONDecoder.store.decode(AppSettings.self, from: defaults)) ?? AppSettings.fallback
    }

    func save(_ settings: AppSettings) throws {
        try store.write(settings, to: Self.fileName)
    }
}

extension AppSettings {
    /// Only used if even the bundled defaults are unreadable (the app then shows the config error).
    static let fallback = AppSettings(
        vault: .init(tasksFolder: "TaskNotes/Tasks", taskTag: "", trashFolder: ".trash"),
        today: .init(arrangement: .sideBySide),
        sources: .init(anchorCalendarIDs: [], reminderListIDs: []),
        day: .init(boundary: .midnight, energyHour: .midnight),
        pool: .init(visibleCount: 3),
        timeline: .init(layout: .oneColumn, range: .aroundNow,
                        wholeDay: .init(start: .midnight, end: .midnight), hoursBefore: 2, hoursAfter: 8,
                        firstHalf: .init(start: .midnight, end: .midnight),
                        secondHalf: .init(start: .midnight, end: .midnight),
                        eventFontSize: 15, taskFontSize: 15),
        notifications: .init(enabled: false),
        onboarding: .init(completed: false),
        colors: [:]
    )
}
