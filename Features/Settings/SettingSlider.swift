import SwiftUI

/// A percentage with a slider that snaps to the step in `rules.json`.
struct SettingSlider: View {
    @Environment(AppModel.self) private var model
    let icon: Icon?
    let title: LocalizedStringKey
    var info: LocalizedStringKey?
    let value: WritableKeyPath<AppSettings, Double>
    let limits: RulesConfig.Limits.Range
    let accessibilityID: String

    var body: some View {
        let current = model.settings[keyPath: value]
        PlateRow(icon: icon, title: title, info: info) { PercentText(value: current) }
        Slider(value: Binding(get: { current }, set: { new in model.updateSettings { $0[keyPath: value] = limits.snapped(new) } }),
               in: limits.closed)
            .accessibilityIdentifier(accessibilityID)
    }
}

/// A share as a whole percent, in the secondary color, as a row's value.
struct PercentText: View {
    @Environment(\.tokens) private var tokens
    let value: Double

    var body: some View {
        Text(value.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit().foregroundStyle(tokens.color(.secondaryText))
    }
}
