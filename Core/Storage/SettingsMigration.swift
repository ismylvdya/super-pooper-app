import Foundation

/// Settings older versions stored that the current one no longer has, dropped as they are read (this device's settings
/// file and the vault's settings), so nothing that uses the settings has to know about them.
enum SettingsMigration {
    /// Colors older versions let the user pick and the current one does not: the accent (the interface became black and
    /// white), the Twice and the missed-day colors (drawn nowhere).
    static let retiredColors: Set<String> = ["accent", "twice", "missed"]

    static func migrated(_ settings: AppSettings) -> AppSettings {
        var settings = settings
        settings.colors = settings.colors.filter { !retiredColors.contains($0.key) }
        return settings
    }
}
