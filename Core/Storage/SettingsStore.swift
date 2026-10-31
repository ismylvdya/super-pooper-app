import Foundation

/// User settings shared by the app and the widgets.
struct SettingsStore: Sendable {
    static let fileName = "settings.json"

    let store: JSONFileStore
    let defaults: DefaultSettings

    /// Stored values over defaults; a broken file falls back to defaults.
    func load() -> AppSettings {
        guard let stored = store.readData(Self.fileName),
              let merged = try? JSONMerge.merge(base: defaults.json, overlay: stored),
              let settings = try? JSONDecoder.store.decode(AppSettings.self, from: merged) else { return defaults.values }
        return settings
    }

    func save(_ settings: AppSettings) throws {
        try store.write(settings, to: Self.fileName)
    }
}

/// The bundled `defaults.json`: the JSON user settings are merged over (new fields of a new version get their default),
/// and its values, checked when the configs load.
struct DefaultSettings: Sendable {
    let json: Data
    let values: AppSettings
}
