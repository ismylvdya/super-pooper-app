import SwiftUI

/// Color, harmful, repeatable task, Today, routine, twice a day.
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
            toggle(.today, "habitPage.showInToday", "info.habitPage.showInToday", \.showInToday, TaskEdit.showInToday)
            PlateRow(icon: .colors, title: "habitPage.color") {
                // Reset: back to the habit color from the settings.
                HexColorField(color: tokens.habitColor(editor.task), stored: options.color, accessibilityID: "habitPage.color") {
                    editor.apply([.habitColor($0)])
                }
            }
            toggle(.harmful, "habitPage.harmful", "info.habitPage.harmful", \.harmful, TaskEdit.harmful)
            PlateRow(icon: .timeOfDay, title: "habitPage.timeOfDay", info: "info.habitPage.timeOfDay") {
                Picker("habitPage.timeOfDay", selection: Binding(
                    get: { options.timeOfDay },
                    set: { editor.apply([.timeOfDay($0)]) }
                )) {
                    Text("habitPage.timeOfDay.any").tag(HabitTimeOfDay?.none)
                    ForEach(HabitTimeOfDay.allCases, id: \.self) { Text(LocalizedStringKey(String("habitPage.timeOfDay.") + $0.rawValue)).tag(HabitTimeOfDay?.some($0)) }
                }
                .labelsHidden()
            }
            toggle(.habitMarkTwice, "habitPage.twiceADay", "info.habitPage.twiceADay", \.twiceADay, TaskEdit.twiceADay)
            if options.twiceADay {
                PlateRow(icon: nil, title: "habitPage.twiceCountsDouble", indent: true) {
                    Toggle("habitPage.twiceCountsDouble", isOn: binding(\.twiceCountsDouble, TaskEdit.twiceCountsDouble)).labelsHidden()
                }
            }
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
