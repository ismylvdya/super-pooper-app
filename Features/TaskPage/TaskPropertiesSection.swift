import SwiftUI

/// What the chips and the date sheet do not set: a task's status and estimate. A habit's stand in `HabitDaySection`.
struct TaskPropertiesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateSection(header: "taskPage.properties", info: "info.taskPage.properties") {
            statusRow
            PlateRow(icon: .estimate, title: "taskPage.estimate", info: "info.taskPage.estimate") {
                Picker("taskPage.estimate", selection: estimateBinding) {
                    ForEach(rules.timeEstimates, id: \.minutes) { Text(LocalizedStringKey($0.label)).tag($0.minutes) }
                }
                .labelsHidden()
            }
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

    private var estimateBinding: Binding<Int> {
        Binding(get: { rules.day.estimate(of: task) },
                set: { minutes in editor.apply([.timeEstimate(minutes)]) })
    }
}
