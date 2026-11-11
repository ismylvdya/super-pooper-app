import SwiftUI

struct PoolSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let isActive = model.settings.poolUsesVisibleCount
        PlateSection(header: "settings.pool", hint: isActive ? "settings.pool.hint" : "settings.pool.hint.sideBySide") {
            SettingsLink(route: .poolOrder, icon: .resetOrder, title: "sort.title")
            SettingsLink(route: .chipOrder, icon: .chipOrder, title: "chipOrder.title")
            SettingChoice(icon: .high, title: "settings.pool.highPriority", info: "info.settings.pool.highPriority",
                          value: \.pool.highPriorityLook, options: model.config.rules.pool.highPriorityLooks,
                          prefix: "settings.pool.highPriority.", accessibilityID: "settings.pool.highPriority")
            PlateRow(icon: nil, title: "settings.pool.highColor") { ThemeColorField(token: .high) }
            selectionOutline
            subtaskLines
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

    /// How solid the outline of a picked task is, over the color of the section titles.
    /// How the lines from a parent to its subtasks turn: how round, and whether a turn the line goes on past is round too.
    @ViewBuilder private var subtaskLines: some View {
        SettingSlider(icon: .subtask, title: "settings.pool.subtaskLineCorner", value: \.pool.subtaskLineCorner,
                      limits: model.config.rules.limits.subtaskLineCorner, accessibilityID: "settings.pool.subtaskLineCorner",
                      samplePlate: nil) { PointsText(value: $0) }
        PlateRow(icon: nil, title: "settings.pool.subtaskLineRoundsMiddle", info: "info.settings.pool.subtaskLineRoundsMiddle") {
            SwitchToggle("settings.pool.subtaskLineRoundsMiddle", isOn: Binding(get: { model.settings.pool.subtaskLineRoundsMiddle },
                                                                                set: { value in model.updateSettings { $0.pool.subtaskLineRoundsMiddle = value } }))
                .labelsHidden()
                .accessibilityIdentifier("settings.pool.subtaskLineRoundsMiddle")
        }
    }

    private var selectionOutline: some View {
        SettingSlider(icon: .opacity, title: "settings.pool.selectionOutline", info: "info.settings.pool.selectionOutline",
                    value: \.pool.selectionOutlineOpacity, limits: model.config.rules.limits.selectionOutlineOpacity,
                    accessibilityID: "settings.pool.selectionOutline")
    }
}
