import Foundation

/// The part of the settings that lives in the vault (a note next to the tasks folder), so every device
/// and Obsidian see the same: everything except what belongs to this device (the chosen folder, the
/// calendars and lists picked here, onboarding).
struct SyncedSettings: Codable, Equatable, Sendable {
    var taskTag: String
    var obsidianVault: String
    var obsidianPathPrefix: String
    var today: AppSettings.Today
    var day: AppSettings.Day
    var pool: AppSettings.Pool
    var timeline: AppSettings.Timeline
    var notifications: AppSettings.Notifications
    var habits: AppSettings.Habits
    var clock: AppSettings.Clock
    var appearance: AppSettings.Appearance
    var colors: [String: String]

    init(_ settings: AppSettings) {
        taskTag = settings.vault.taskTag
        obsidianVault = settings.vault.obsidianVault
        obsidianPathPrefix = settings.vault.obsidianPathPrefix
        today = settings.today
        day = settings.day
        pool = settings.pool
        timeline = settings.timeline
        notifications = settings.notifications
        habits = settings.habits
        clock = settings.clock
        appearance = settings.appearance
        colors = settings.colors
    }

    func applied(to settings: AppSettings) -> AppSettings {
        var result = settings
        result.vault.taskTag = taskTag
        result.vault.obsidianVault = obsidianVault
        result.vault.obsidianPathPrefix = obsidianPathPrefix
        result.today = today
        result.day = day
        result.pool = pool
        result.timeline = timeline
        result.notifications = notifications
        result.habits = habits
        result.clock = clock
        result.appearance = appearance
        result.colors = colors
        return result
    }

    /// The note's JSON over `settings`: keys missing in the note (an older version wrote it) keep
    /// their current values; an unreadable note changes nothing. The color overrides are a list of the
    /// user's entries, not a structure: when the note has them they replace the local ones (a color reset on
    /// another device stays reset).
    static func merged(note json: Data, over settings: AppSettings) -> AppSettings {
        guard let current = try? JSONEncoder.store.encode(SyncedSettings(settings)),
              let merged = try? JSONMerge.merge(base: current, overlay: json),
              var synced = try? JSONDecoder.store.decode(SyncedSettings.self, from: merged) else { return settings }
        if let colors = (try? JSONDecoder.store.decode(NoteColors.self, from: json))?.colors { synced.colors = colors }
        return synced.applied(to: settings)
    }

    private struct NoteColors: Decodable {
        let colors: [String: String]?
    }
}
