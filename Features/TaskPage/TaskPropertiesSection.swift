import SwiftUI

/// What the chips and the date sheet do not set: a task's status and estimate; a habit (which has no chips) has High,
/// estimate, the time zone of its reminders and feel.
struct TaskPropertiesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateSection(header: "taskPage.properties", info: "info.taskPage.properties") {
            if task.isHabit { highRow } else { statusRow }
            PlateRow(icon: .estimate, title: "taskPage.estimate", info: "info.taskPage.estimate") {
                Picker("taskPage.estimate", selection: estimateBinding) {
                    ForEach(rules.timeEstimates, id: \.minutes) { Text(LocalizedStringKey($0.label)).tag($0.minutes) }
                }
                .labelsHidden()
            }
            if task.isHabit { habitOnlyRows }
        }
    }

    private var highRow: some View {
        PlateRow(icon: .high, title: "taskPage.high", info: "info.taskPage.high", iconTint: tokens.color(.high)) {
            Toggle("taskPage.high", isOn: Binding(get: { task.isHighPriority }, set: { editor.apply([.highPriority($0)]) }))
                .labelsHidden()
                .accessibilityIdentifier("taskPage.high")
        }
    }

    /// The status makes no sense for a habit: it is always active and repeats by its own rule.
    private var statusRow: some View {
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

    @ViewBuilder private var habitOnlyRows: some View {
        TimeZoneRow(editor: editor)
        PlateRow(icon: .feel, title: "taskPage.feel", info: "info.taskPage.feel") {}
        Picker("taskPage.feel", selection: Binding(get: { task.feel }, set: { editor.apply([.feel($0)]) })) {
            ForEach(TaskFeel.allCases, id: \.self) { Text(L10n.string("taskPage.feel." + $0.rawValue)).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("taskPage.feel")
    }

    private var estimateBinding: Binding<Int> {
        Binding(get: { rules.day.estimate(of: task) },
                set: { minutes in editor.apply([.timeEstimate(minutes)]) })
    }
}
