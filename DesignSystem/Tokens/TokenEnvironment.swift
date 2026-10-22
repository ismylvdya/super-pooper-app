import SwiftUI

/// Bundled configs injected into SwiftUI. The composition root sets them explicitly;
/// the defaults (loaded from the bundle) keep previews and widgets working.
private struct TokensKey: EnvironmentKey {
    static let defaultValue: DesignTokens = BundledConfig.tokens
}

private struct IconsKey: EnvironmentKey {
    static let defaultValue: IconSet = BundledConfig.icons
}

private struct ActionsKey: EnvironmentKey {
    static let defaultValue: ActionRegistry = BundledConfig.actions
}

private struct RulesKey: EnvironmentKey {
    static let defaultValue: RulesConfig = BundledConfig.rules
}

extension EnvironmentValues {
    var tokens: DesignTokens {
        get { self[TokensKey.self] }
        set { self[TokensKey.self] = newValue }
    }

    var icons: IconSet {
        get { self[IconsKey.self] }
        set { self[IconsKey.self] = newValue }
    }

    var actions: ActionRegistry {
        get { self[ActionsKey.self] }
        set { self[ActionsKey.self] = newValue }
    }

    var rules: RulesConfig {
        get { self[RulesKey.self] }
        set { self[RulesKey.self] = newValue }
    }
}

extension View {
    func appConfig(_ config: AppConfig) -> some View {
        environment(\.tokens, config.tokens)
            .environment(\.icons, config.icons)
            .environment(\.actions, config.actions)
            .environment(\.rules, config.rules)
    }
}

/// Lazily loaded bundle configs for environment defaults. If a file is broken the app shows
/// the config error screen before any view reads these.
enum BundledConfig {
    static let config: AppConfig? = try? AppConfig.load()

    static var tokens: DesignTokens {
        guard let config else { preconditionFailure("tokens.json is invalid; the config error screen should be shown") }
        return config.tokens
    }

    static var icons: IconSet {
        guard let config else { preconditionFailure("icons.json is invalid") }
        return config.icons
    }

    static var actions: ActionRegistry {
        guard let config else { preconditionFailure("actions.json is invalid") }
        return config.actions
    }

    static var rules: RulesConfig {
        guard let config else { preconditionFailure("rules.json is invalid") }
        return config.rules
    }
}
