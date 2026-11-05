import SwiftUI

/// What is set once for a habit: its color, harmful, twice a day, how missed days count.
struct HabitOptionsSection: View {
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor

    private var options: HabitOptions { editor.task.habit }

    var body: some View {
        PlateSection(header: "habitPage.options", info: "info.habitPage.options") {
            // A task that simply repeats has no color of its own and is not to be got rid of.
            if !options.repeatable {
                PlateRow(icon: .colors, title: "habitPage.color") {
                    // Reset: back to the habit color from the settings.
                    HexColorField(color: tokens.habitColor(editor.task), stored: options.color, accessibilityID: "habitPage.color") {
                        editor.apply([.habitColor($0)])
                    }
                }
                toggle(.harmful, "habitPage.harmful", "info.habitPage.harmful", \.harmful, TaskEdit.harmful)
            }
            toggle(.habitMarkTwice, "habitPage.twiceADay", "info.habitPage.twiceADay", \.twiceADay, TaskEdit.twiceADay)
            if options.twiceADay {
                PlateRow(icon: nil, title: "habitPage.twiceCountsDouble", indent: true) {
                    SwitchToggle("habitPage.twiceCountsDouble", isOn: binding(\.twiceCountsDouble, TaskEdit.twiceCountsDouble)).labelsHidden()
                }
            }
            HabitGoalRows(editor: editor)
        }
    }

    private func toggle(_ icon: Icon, _ title: LocalizedStringKey, _ info: LocalizedStringKey,
                        _ keyPath: KeyPath<HabitOptions, Bool>, _ change: @escaping (Bool) -> TaskEdit) -> some View {
        PlateRow(icon: icon, title: title, info: info) {
            SwitchToggle(title, isOn: binding(keyPath, change)).labelsHidden()
        }
    }

    private func binding(_ keyPath: KeyPath<HabitOptions, Bool>, _ change: @escaping (Bool) -> TaskEdit) -> Binding<Bool> {
        Binding(get: { options[keyPath: keyPath] }, set: { editor.apply([change($0)]) })
    }
}
