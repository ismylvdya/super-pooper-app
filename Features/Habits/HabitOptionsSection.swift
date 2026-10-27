import SwiftUI

/// Color, harmful, repeatable task, Today, routine, twice a day.
struct HabitOptionsSection: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
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
            toggle(.today, "habitPage.showInToday", "info.habitPage.showInToday", \.showInToday, TaskFieldChange.showInToday)
            PlateRow(icon: .colors, title: "habitPage.color") {
                ColorPicker("habitPage.color", selection: Binding(
                    get: { tokens.habitColor(editor.task) },
                    set: { color in editor.apply([.habitColor(UIColor(color).hexString)]) }
                ), supportsOpacity: false)
                .labelsHidden()
                // Back to the habit color from the settings.
                if options.color != nil {
                    Button { editor.apply([.habitColor(nil)]) } label: {
                        Image(systemName: icons[.resetOrder]).foregroundStyle(tokens.color(.secondaryText))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("settings.colors.reset"))
                }
            }
            toggle(.harmful, "habitPage.harmful", "info.habitPage.harmful", \.harmful, TaskFieldChange.harmful)
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
            toggle(.habitMarkTwice, "habitPage.twiceADay", "info.habitPage.twiceADay", \.twiceADay, TaskFieldChange.twiceADay)
            if options.twiceADay {
                PlateRow(icon: nil, title: "habitPage.twiceCountsDouble", indent: true) {
                    Toggle("habitPage.twiceCountsDouble", isOn: binding(\.twiceCountsDouble, TaskFieldChange.twiceCountsDouble)).labelsHidden()
                }
            }
        }
    }

    private func toggle(_ icon: Icon, _ title: LocalizedStringKey, _ info: LocalizedStringKey,
                        _ keyPath: KeyPath<HabitOptions, Bool>, _ change: @escaping (Bool) -> TaskFieldChange) -> some View {
        PlateRow(icon: icon, title: title, info: info) {
            Toggle(title, isOn: binding(keyPath, change)).labelsHidden()
        }
    }

    private func binding(_ keyPath: KeyPath<HabitOptions, Bool>, _ change: @escaping (Bool) -> TaskFieldChange) -> Binding<Bool> {
        Binding(get: { options[keyPath: keyPath] }, set: { editor.apply([change($0)]) })
    }
}
