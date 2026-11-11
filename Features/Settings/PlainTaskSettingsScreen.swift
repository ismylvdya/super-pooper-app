import SwiftUI

/// What only plain tasks have: a task's own color, and how a started one looks (habits and repeatable tasks are marked
/// day by day instead).
struct PlainTaskSettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        PageScaffold(title: L10n.string("settings.plainTasks.summary")) {
            PlateSection(header: "settings.colors") {
                ForEach(tokens.editableColors[.tasks], id: \.self) { token in
                    PlateRow(icon: nil, title: LocalizedStringKey(String("color.") + token.rawValue)) { ThemeColorField(token: token) }
                }
            }
            PlateSection(header: "settings.plainTasks.started") {
                lookPicker
                if model.settings.pool.startedLook == .fill {
                    startedFill
                    SwitchToggle("settings.pool.startedTitleAfterFill", isOn: Binding(
                        get: { model.settings.pool.startedTitleAfterFill },
                        set: { value in model.updateSettings { $0.pool.startedTitleAfterFill = value } }))
                        .accessibilityIdentifier("settings.pool.startedTitleAfterFill")
                } else {
                    circleSize
                    SettingSlider(icon: nil, title: "settings.pool.startedFadeMiddle", value: \.pool.startedFadeMiddle,
                                  limits: model.config.rules.limits.startedFadeMiddle, accessibilityID: "settings.pool.startedFadeMiddle")
                    SettingSlider(icon: nil, title: "settings.pool.startedFadeWidth", value: \.pool.startedFadeWidth,
                                  limits: model.config.rules.limits.startedFadeWidth, accessibilityID: "settings.pool.startedFadeWidth")
                    SettingSlider(icon: nil, title: "settings.pool.startedTitleGap", info: "info.settings.pool.startedTitleGap",
                                  value: \.pool.startedTitleGap, limits: model.config.rules.limits.startedTitleGap,
                                  accessibilityID: "settings.pool.startedTitleGap", samplePlate: nil) { PointsText(value: $0) }
                }
                PlateRow(icon: nil, title: "settings.pool.startedColor") { ThemeColorField(token: .started) }
            }
        }
    }

    /// The fill over the plate, or a circle before the name.
    private var lookPicker: some View {
        SettingChoice(icon: nil, title: "settings.pool.startedLook", value: \.pool.startedLook, options: AppSettings.StartedLook.allCases,
                      prefix: "settings.pool.startedLook.", accessibilityID: "settings.pool.startedLook")
    }

    /// How far a started task's fill reaches, with a sample of it, as it stands in the pool: on a row's whole plate.
    private var startedFill: some View {
        SettingSlider(icon: nil, title: "settings.pool.startedFill", info: "info.settings.pool.startedFill", value: \.pool.startedFillLength,
                    limits: model.config.rules.limits.startedFillLength, accessibilityID: "settings.pool.startedFill",
                    samplePlate: AnyView(StartedFill(length: model.settings.pool.startedFillLength))) { PercentText(value: $0) }
    }

    /// How big the circle is, with a sample of it at that size: from a small letter of a name to a one-line plate.
    private var circleSize: some View {
        let sizes = tokens.startedCircleSizes
        return SettingSlider(icon: nil, title: "settings.pool.startedCircleSize", value: \.pool.startedCircleSize,
                           limits: model.config.rules.limits.startedCircleSize, accessibilityID: "settings.pool.startedCircleSize",
                           samplePlate: nil) { size in
            let diameter = sizes.lowerBound + (sizes.upperBound - sizes.lowerBound) * size
            StartedCircle().frame(width: diameter, height: diameter).frame(width: sizes.upperBound, height: sizes.upperBound)
        }
    }
}
