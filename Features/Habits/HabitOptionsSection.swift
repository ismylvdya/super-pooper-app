import SwiftUI

/// Color, harmful, repeatable task, Today, routine, twice a day.
struct HabitOptionsSection: View {
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor

    private var options: HabitOptions { editor.task.habit }

    var body: some View {
        PlateSection(header: "habitPage.options", info: "info.habitPage.options") {
            toggle(.today, "habitPage.showInToday", "info.habitPage.showInToday", \.showInToday, TaskFieldChange.showInToday)
            PlateRow(icon: .colors, title: "habitPage.color") {
                ColorPicker("habitPage.color", selection: Binding(
                    get: { tokens.habitColor(editor.task) },
                    set: { color in editor.apply([.habitColor(UIColor(color).hexString)]) }
                ), supportsOpacity: false)
                .labelsHidden()
            }
            toggle(.harmful, "habitPage.harmful", "info.habitPage.harmful", \.harmful, TaskFieldChange.harmful)
            toggle(.recurrence, "habitPage.repeatable", "info.habitPage.repeatable", \.repeatable, TaskFieldChange.repeatable)
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
