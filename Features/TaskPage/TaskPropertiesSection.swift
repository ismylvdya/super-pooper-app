import SwiftUI

/// High, date, status, estimate, how the task feels; a habit has High, estimate and feel.
struct TaskPropertiesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateSection(header: "taskPage.properties", info: "info.taskPage.properties") {
            PlateRow(icon: .high, title: "taskPage.high", info: "info.taskPage.high", iconTint: tokens.color(.high)) {
                Toggle("taskPage.high", isOn: Binding(get: { task.isHighPriority }, set: { editor.apply([.highPriority($0)]) }))
                    .labelsHidden()
                    .accessibilityIdentifier("taskPage.high")
            }
            if !task.isHabit { taskOnlyRows }
            PlateRow(icon: .estimate, title: "taskPage.estimate", info: "info.taskPage.estimate") {
                Picker("taskPage.estimate", selection: estimateBinding) {
                    ForEach(rules.timeEstimates, id: \.minutes) { Text(LocalizedStringKey($0.label)).tag($0.minutes) }
                }
                .labelsHidden()
            }
            TimeZoneRow(editor: editor)
            PlateRow(icon: .feel, title: "taskPage.feel", info: "info.taskPage.feel") {}
            Picker("taskPage.feel", selection: binding(\.feel, change: TaskEdit.feel)) {
                ForEach(TaskFeel.allCases, id: \.self) { Text(L10n.string("taskPage.feel." + $0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("taskPage.feel")
        }
    }

    /// The status makes no sense for a habit: it is always active and repeats by its own rule.
    @ViewBuilder private var taskOnlyRows: some View {
        DueEditor(editor: editor)
        PlateRow(icon: .status, title: "taskPage.status", info: "info.taskPage.status") {
            Picker("taskPage.status", selection: Binding(
                get: { task.status },
                set: { status in editor.setStatus(status, today: model.context().today) }
            )) {
                ForEach(TaskStatus.known, id: \.self) { Text(StatusText.title($0)).tag($0) }
                if case .other(let raw) = task.status { Text(verbatim: raw).tag(task.status) }
            }
            .labelsHidden()
        }
    }

    private func binding<Value>(_ keyPath: KeyPath<TaskItem, Value>, change: @escaping (Value) -> TaskEdit) -> Binding<Value> {
        Binding(get: { task[keyPath: keyPath] },
                set: { value in editor.apply([change(value)]) })
    }

    private var estimateBinding: Binding<Int> {
        Binding(get: { rules.day.estimate(of: task) },
                set: { minutes in editor.apply([.timeEstimate(minutes)]) })
    }
}
