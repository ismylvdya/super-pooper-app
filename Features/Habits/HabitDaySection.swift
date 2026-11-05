import SwiftUI

/// How a habit stands in the pool: whether it is there at all and, if it is, its priority, routine, feel and how long it
/// takes (they sort it and show as its icons).
struct HabitDaySection: View {
    @Environment(\.rules) private var rules
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateSection(header: "habitPage.day") {
            PlateRow(icon: .today, title: "habitPage.showInToday", info: "info.habitPage.showInToday") {
                SwitchToggle("habitPage.showInToday", isOn: Binding(get: { task.habit.showInToday }, set: { editor.apply([.showInToday($0)]) }))
                    .labelsHidden()
            }
            Group {
                PlateRow(icon: .high, title: "taskPage.high", info: "info.taskPage.high") {
                    SwitchToggle("taskPage.high", isOn: Binding(get: { task.isHighPriority }, set: { editor.apply([.highPriority($0)]) }))
                        .labelsHidden()
                        .accessibilityIdentifier("taskPage.high")
                }
                PlateRow(icon: .timeOfDay, title: "habitPage.timeOfDay", info: "info.habitPage.timeOfDay") {
                    Picker("habitPage.timeOfDay", selection: Binding(get: { task.habit.timeOfDay }, set: { editor.apply([.timeOfDay($0)]) })) {
                        Text("habitPage.timeOfDay.any").tag(HabitTimeOfDay?.none)
                        ForEach(HabitTimeOfDay.allCases, id: \.self) { Text(LocalizedStringKey(String("habitPage.timeOfDay.") + $0.rawValue)).tag(HabitTimeOfDay?.some($0)) }
                    }
                    .labelsHidden()
                }
                FeelPicker(editor: editor)
                PlateRow(icon: .estimate, title: "taskPage.estimate", info: "info.taskPage.estimate") {
                    Picker("taskPage.estimate", selection: Binding(get: { rules.day.estimate(of: task) }, set: { editor.apply([.timeEstimate($0)]) })) {
                        ForEach(rules.estimateOptions(including: rules.day.estimate(of: task)), id: \.minutes) { Text(LocalizedStringKey($0.label)).tag($0.minutes) }
                    }
                    .labelsHidden()
                }
            }
            .disabled(!task.habit.showInToday)
        }
    }
}
