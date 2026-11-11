import SwiftUI

/// A setting that is a number within its limits (`rules.json` → `limits`): a row with its title and, on the right, its
/// value (a share in percent by default, or points, or a sample of what it sets), and under it the slider, snapped to
/// the limits' step. Every such number in the settings is set this way.
struct SettingSlider<Trailing: View>: View {
    @Environment(AppModel.self) private var model
    let icon: Icon?
    let title: LocalizedStringKey
    var info: LocalizedStringKey?
    let value: WritableKeyPath<AppSettings, Double>
    let limits: RulesConfig.Limits.Range
    let accessibilityID: String
    /// The row itself is the sample: on a task's plate, with this drawn over it (`PlateFill`).
    var samplePlate: AnyView?
    @ViewBuilder let trailing: (Double) -> Trailing

    var body: some View {
        let current = model.settings[keyPath: value]
        if let samplePlate {
            row(current).rowPlatePadding().environment(\.plateGradient, samplePlate).plate(.row)
        } else {
            row(current)
        }
        Slider(value: Binding(get: { current }, set: { new in model.updateSettings { $0[keyPath: value] = limits.snapped(new) } }),
               in: limits.closed)
            .accessibilityIdentifier(accessibilityID)
    }

    private func row(_ current: Double) -> some View {
        PlateRow(icon: icon, title: title, info: info) { trailing(current) }
    }
}

extension SettingSlider where Trailing == PercentText {
    /// The share in percent on the right.
    init(icon: Icon?, title: LocalizedStringKey, info: LocalizedStringKey? = nil, value: WritableKeyPath<AppSettings, Double>,
         limits: RulesConfig.Limits.Range, accessibilityID: String) {
        self.init(icon: icon, title: title, info: info, value: value, limits: limits, accessibilityID: accessibilityID, samplePlate: nil) {
            PercentText(value: $0)
        }
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

/// Points as a row's value, in the secondary color.
struct PointsText: View {
    @Environment(\.tokens) private var tokens
    let value: Double

    var body: some View {
        Text(L10n.format("settings.points", Int(value.rounded()))).monospacedDigit().foregroundStyle(tokens.color(.secondaryText))
    }
}
