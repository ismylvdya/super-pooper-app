import Foundation

/// All bundled configs, loaded and validated once at start-up (composition root and widgets).
struct AppConfig: Sendable {
    enum File {
        static let tokens = "tokens.json"
        static let icons = "icons.json"
        static let actions = "actions.json"
        static let todayLayout = "today.layout.json"
        static let sort = "sort.json"
        static let fieldMapping = "field-mapping.json"
        static let flags = "feature-flags.json"
        static let rules = "rules.json"
        static let defaults = "defaults.json"
    }

    let tokens: DesignTokens
    let icons: IconSet
    let actions: ActionRegistry
    let todayLayout: ScreenLayout
    let sort: SortConfig
    let fieldMapping: FieldMapping
    let flags: FeatureFlags
    let rules: RulesConfig
    /// Raw `defaults.json`; user settings are merged over it.
    let defaultSettings: Data

    static func load(bundle: Bundle = .main) throws -> AppConfig {
        let loader = ConfigLoader(bundle: bundle)
        let actions = try loader.load(ActionRegistry.self, from: File.actions)
        try actions.validate(file: File.actions)
        let defaults = try loader.data(File.defaults)
        _ = try ConfigLoader.decode(AppSettings.self, from: defaults, file: File.defaults)
        return AppConfig(
            tokens: try loader.load(DesignTokens.self, from: File.tokens),
            icons: try loader.load(IconSet.self, from: File.icons),
            actions: actions,
            todayLayout: try loader.load(ScreenLayout.self, from: File.todayLayout),
            sort: try loader.load(SortConfig.self, from: File.sort),
            fieldMapping: try loader.load(FieldMapping.self, from: File.fieldMapping),
            flags: try loader.load(FeatureFlags.self, from: File.flags),
            rules: try loader.load(RulesConfig.self, from: File.rules),
            defaultSettings: defaults
        )
    }
}
