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
                startedFill
                PlateRow(icon: nil, title: "settings.pool.startedColor") { ThemeColorField(token: .started) }
            }
        }
    }

    /// How far a started task's fill reaches, with a sample of it, as it stands in the pool: on a row's whole plate.
    @ViewBuilder private var startedFill: some View {
        let length = model.settings.pool.startedFillLength
        let limits = model.config.rules.limits.startedFillLength
        PlateRow(icon: nil, title: "settings.pool.startedFill", info: "info.settings.pool.startedFill") {
            Text(length.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit().foregroundStyle(tokens.color(.secondaryText))
        }
        .rowPlatePadding()
        .environment(\.plateGradient, AnyView(StartedFill(length: length)))
        .plate(.row)
        Slider(value: Binding(get: { length }, set: { value in model.updateSettings { $0.pool.startedFillLength = limits.snapped(value) } }),
               in: limits.closed)
            .accessibilityIdentifier("settings.pool.startedFill")
    }
}
