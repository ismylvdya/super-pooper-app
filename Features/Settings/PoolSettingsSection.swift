import SwiftUI

struct PoolSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let isActive = model.settings.poolUsesVisibleCount
        PlateSection(header: "settings.pool", hint: isActive ? "settings.pool.hint" : "settings.pool.hint.sideBySide") {
            SettingsLink(route: .poolOrder, icon: .resetOrder, title: "sort.title")
            SettingsLink(route: .chipOrder, icon: .chipOrder, title: "chipOrder.title")
            PlateRow(icon: .high, title: "settings.pool.highPriority", info: "info.settings.pool.highPriority",
                     iconTint: tokens.color(.high)) {}
            Picker("settings.pool.highPriority", selection: Binding(
                get: { model.settings.pool.highPriorityLook },
                set: { look in model.updateSettings { $0.pool.highPriorityLook = look } })) {
                ForEach(model.config.rules.pool.highPriorityLooks, id: \.self) { look in
                    Text(LocalizedStringKey(String("settings.pool.highPriority.") + look.rawValue)).tag(look)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.pool.highPriority")
            PlateRow(icon: nil, title: "settings.pool.highColor") { ThemeColorField(token: .high) }
            startedFill
            PlateRow(icon: nil, title: "settings.pool.startedColor") { ThemeColorField(token: .started) }
            PlateRow(icon: .poolCount, title: "settings.pool.visible", info: "info.settings.pool.visible") {
                Stepper(value: Binding(get: { model.settings.pool.visibleCount },
                                       set: { value in model.updateSettings { $0.pool.visibleCount = value } }), in: model.config.rules.limits.poolVisibleCount.ints) {
                    Text(verbatim: "\(model.settings.pool.visibleCount)")
                }
                .fixedSize()
            }
            .disabled(!isActive)
            .opacity(isActive ? 1 : tokens.opacity(.blocked))
        }
    }

    /// How far a started task's blue fill reaches, with a sample of it.
    @ViewBuilder private var startedFill: some View {
        let length = model.settings.pool.startedFillLength
        let limits = model.config.rules.limits.startedFillLength
        PlateRow(icon: nil, title: "settings.pool.startedFill", info: "info.settings.pool.startedFill") {
            Text(length.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit().foregroundStyle(tokens.color(.secondaryText))
        }
        .background { StartedFill(length: length) }
        Slider(value: Binding(get: { length }, set: { value in model.updateSettings { $0.pool.startedFillLength = limits.snapped(value) } }),
               in: limits.closed)
            .accessibilityIdentifier("settings.pool.startedFill")
    }
}
