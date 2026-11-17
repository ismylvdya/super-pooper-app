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
                fillMiddle
                fillWidth
                SettingSlider(icon: nil, title: "settings.pool.startedTitleGap", info: "info.settings.pool.startedTitleGap",
                              value: \.pool.startedTitleGap, limits: model.config.rules.limits.startedTitleGap,
                              accessibilityID: "settings.pool.startedTitleGap", samplePlate: nil) { PointsText(value: $0) }
                PlateRow(icon: nil, title: "settings.pool.startedColor") { ThemeColorField(token: .started) }
            }
        }
    }

    /// Where the fill's transition stands and how wide it is, each with a sample of the fill as it stands in the pool: on a
    /// row's whole plate (D-192).
    private var fillMiddle: some View {
        SettingSlider(icon: nil, title: "settings.pool.startedFillMiddle", info: "info.settings.pool.startedFillMiddle",
                      value: \.pool.startedFillMiddle, limits: model.config.rules.limits.startedFillMiddle,
                      accessibilityID: "settings.pool.startedFillMiddle", samplePlate: sampleFill) { PercentText(value: $0) }
    }

    private var fillWidth: some View {
        SettingSlider(icon: nil, title: "settings.pool.startedFillWidth", info: "info.settings.pool.startedFillWidth",
                      value: \.pool.startedFillWidth, limits: model.config.rules.limits.startedFillWidth,
                      accessibilityID: "settings.pool.startedFillWidth", samplePlate: sampleFill) { PercentText(value: $0) }
    }

    private var sampleFill: AnyView { AnyView(StartedFill(StartedLayout(model.settings.pool))) }

}
