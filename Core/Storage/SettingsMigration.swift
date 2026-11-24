import Foundation

/// Settings older versions stored that the current one no longer has, dropped as they are read (this device's settings
/// file and the vault's settings), so nothing that uses the settings has to know about them. Fields a struct no longer
/// has (the day routine) are read past by the decoder and not written back.
enum SettingsMigration {
    /// Retired color settings, including the old Start fill color in both appearances.
    static let retiredColors: Set<String> = ["accent", "twice", "missed", "started", "started.dark"]

    static func migrated(_ settings: AppSettings) -> AppSettings {
        var settings = settings
        settings.colors = settings.colors.filter { !retiredColors.contains($0.key) }
        settings.pool.criteria = settings.pool.criteria.filter { PoolSortCriterion(rawValue: $0) != nil }
        return settings
    }
}
