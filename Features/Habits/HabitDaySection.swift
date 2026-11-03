import SwiftUI

/// How a habit stands in the day, what is changed most after its schedule: shown in Today, its routine, its feel, High
/// and how long it takes (they sort it in the pool and show as its icons).
struct HabitDaySection: View {
    @Environment(\.rules) private var rules
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateSection(header: "habitPage.day") {
            PlateRow(icon: .today, title: "habitPage.showInToday", info: "info.habitPage.showInToday") {
                Toggle("habitPage.showInToday", isOn: Binding(get: { task.habit.showInToday }, set: { editor.apply([.showInToday($0)]) }))
                    .labelsHidden()
            }
            PlateRow(icon: .timeOfDay, title: "habitPage.timeOfDay", info: "info.habitPage.timeOfDay") {
                Picker("habitPage.timeOfDay", selection: Binding(get: { task.habit.timeOfDay }, set: { editor.apply([.timeOfDay($0)]) })) {
                    Text("habitPage.timeOfDay.any").tag(HabitTimeOfDay?.none)
                    ForEach(HabitTimeOfDay.allCases, id: \.self) { Text(LocalizedStringKey(String("habitPage.timeOfDay.") + $0.rawValue)).tag(HabitTimeOfDay?.some($0)) }
                }
                .labelsHidden()
            }
            PlateRow(icon: .feel, title: "taskPage.feel", info: "info.taskPage.feel") {}
            Picker("taskPage.feel", selection: Binding(get: { task.feel }, set: { editor.apply([.feel($0)]) })) {
                ForEach(TaskFeel.allCases, id: \.self) { Text(L10n.string("taskPage.feel." + $0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("taskPage.feel")
            PlateRow(icon: .high, title: "taskPage.high", info: "info.taskPage.high", iconTint: tokens.color(.high)) {
                Toggle("taskPage.high", isOn: Binding(get: { task.isHighPriority }, set: { editor.apply([.highPriority($0)]) }))
                    .labelsHidden()
                    .accessibilityIdentifier("taskPage.high")
            }
            PlateRow(icon: .estimate, title: "taskPage.estimate", info: "info.taskPage.estimate") {
                Picker("taskPage.estimate", selection: Binding(get: { rules.day.estimate(of: task) }, set: { editor.apply([.timeEstimate($0)]) })) {
                    ForEach(rules.timeEstimates, id: \.minutes) { Text(LocalizedStringKey($0.label)).tag($0.minutes) }
                }
                .labelsHidden()
            }
        }
    }
}
