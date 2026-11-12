import SwiftUI

/// What the chips and the date sheet do not set: a task's status, how it feels, its estimate and, last, Show as project. A habit's stand in
/// `HabitDaySection`.
struct TaskPropertiesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateSection(header: "taskPage.properties", info: "info.taskPage.properties") {
            statusRow
            FeelPicker(editor: editor)
            PlateRow(icon: .estimate, title: "taskPage.estimate", info: "info.taskPage.estimate") {
                Picker("taskPage.estimate", selection: estimateBinding) {
                    ForEach(rules.estimateOptions(including: rules.day.estimate(of: task)), id: \.minutes) { Text(LocalizedStringKey($0.label)).tag($0.minutes) }
                }
                .labelsHidden()
            }
            ShowAsProjectRow(editor: editor)
        }
    }

    /// The row shows the status's name alone, the menu each with its icon. An archived task's status has its own action in the "…"
    /// menu, and no place here.
    private var statusRow: some View {
        PlateRow(icon: .status, title: "taskPage.status", info: "info.taskPage.status") {
            Menu {
                StatusChoiceMenu(levels: TaskStatus.known, current: task.status,
                                 onPick: { editor.setStatus($0, today: model.context().today) })
            } label: {
                AlarmSoundValue(shown: StatusText.title(task.status))
            }
            .accessibilityIdentifier("taskPage.status")
        }
    }

    private var estimateBinding: Binding<Int> {
        Binding(get: { rules.day.estimate(of: task) },
                set: { minutes in editor.apply([.timeEstimate(minutes)]) })
    }
}

/// A list in the picker, with its icon (`TaskListIcons`).
