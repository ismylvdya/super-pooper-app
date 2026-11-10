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
                }
                PlateRow(icon: nil, title: "settings.pool.startedColor") { ThemeColorField(token: .started) }
            }
        }
    }

    /// The fill over the plate, or a circle before the name.
    private var lookPicker: some View {
        Picker("settings.pool.startedLook", selection: Binding(
            get: { model.settings.pool.startedLook },
            set: { look in model.updateSettings { $0.pool.startedLook = look } })) {
            ForEach(AppSettings.StartedLook.allCases, id: \.self) { look in
                Text(LocalizedStringKey(String("settings.pool.startedLook.") + look.rawValue)).tag(look)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("settings.pool.startedLook")
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

    /// How big the circle is, with a sample of it at that size: from a small letter of a name to a one-line plate.
    @ViewBuilder private var circleSize: some View {
        let size = model.settings.pool.startedCircleSize
        let limits = model.config.rules.limits.startedCircleSize
        let sizes = tokens.startedCircleSizes
        PlateRow(icon: nil, title: "settings.pool.startedCircleSize") {
            StartedCircle().frame(width: sizes.lowerBound + (sizes.upperBound - sizes.lowerBound) * size,
                                  height: sizes.lowerBound + (sizes.upperBound - sizes.lowerBound) * size)
                .frame(width: sizes.upperBound, height: sizes.upperBound)
        }
        Slider(value: Binding(get: { size }, set: { value in model.updateSettings { $0.pool.startedCircleSize = limits.snapped(value) } }),
               in: limits.closed)
            .accessibilityIdentifier("settings.pool.startedCircleSize")
    }
}
