import SwiftUI

/// What is set once for a habit: what kind of note it is, its color, harmful, twice a day, the time zone of its reminders.
struct HabitOptionsSection: View {
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor

    private var options: HabitOptions { editor.task.habit }

    var body: some View {
        PlateSection(header: "habitPage.options", info: "info.habitPage.options") {
            // What the note is: a habit to keep track of or a task that simply repeats.
            PlateRow(icon: .recurrence, title: "habitPage.kind", info: "info.habitPage.repeatable") {}
            Picker("habitPage.kind", selection: Binding(get: { options.repeatable }, set: { editor.apply([.repeatable($0)]) })) {
                Text("habitPage.kind.habit").tag(false)
                Text("habitPage.kind.repeatable").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("habitPage.kind")
            PlateRow(icon: .colors, title: "habitPage.color") {
                // Reset: back to the habit color from the settings.
                HexColorField(color: tokens.habitColor(editor.task), stored: options.color, accessibilityID: "habitPage.color") {
                    editor.apply([.habitColor($0)])
                }
            }
            toggle(.harmful, "habitPage.harmful", "info.habitPage.harmful", \.harmful, TaskEdit.harmful)
            toggle(.habitMarkTwice, "habitPage.twiceADay", "info.habitPage.twiceADay", \.twiceADay, TaskEdit.twiceADay)
            if options.twiceADay {
                PlateRow(icon: nil, title: "habitPage.twiceCountsDouble", indent: true) {
                    Toggle("habitPage.twiceCountsDouble", isOn: binding(\.twiceCountsDouble, TaskEdit.twiceCountsDouble)).labelsHidden()
                }
            }
            TimeZoneRow(editor: editor)
        }
    }

    private func toggle(_ icon: Icon, _ title: LocalizedStringKey, _ info: LocalizedStringKey,
                        _ keyPath: KeyPath<HabitOptions, Bool>, _ change: @escaping (Bool) -> TaskEdit) -> some View {
        PlateRow(icon: icon, title: title, info: info) {
            Toggle(title, isOn: binding(keyPath, change)).labelsHidden()
        }
    }

    private func binding(_ keyPath: KeyPath<HabitOptions, Bool>, _ change: @escaping (Bool) -> TaskEdit) -> Binding<Bool> {
        Binding(get: { options[keyPath: keyPath] }, set: { editor.apply([change($0)]) })
    }
}
