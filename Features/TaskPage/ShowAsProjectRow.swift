import SwiftUI

/// Show as project, at the bottom of a task's settings once it has a subtask: the task is shown on the Lists page under
/// Projects and stays out of the pool itself (`TaskItem.showsAsProject`).
struct ShowAsProjectRow: View {
    @Environment(AppModel.self) private var model
    let editor: TaskEditor

    var body: some View {
        if !editor.task.isHabit, editor.hasSubtasks(in: model) {
            PlateRow(icon: .project, title: "taskPage.showsAsProject", info: "info.taskPage.showsAsProject") {
                SwitchToggle("taskPage.showsAsProject", isOn: Binding(get: { editor.task.showsAsProject },
                                                                     set: { editor.apply([.showsAsProject($0)]) }))
                    .labelsHidden()
                    .accessibilityIdentifier("taskPage.showsAsProject")
            }
        }
    }
}

extension TaskEditor {
    /// The task has a subtask: a draft one typed in, or a note naming it as its parent.
    func hasSubtasks(in model: AppModel) -> Bool {
        if let draft {
            return draft.wrappedValue.subtasks.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        return !model.subtasks(of: task.name).isEmpty
    }
}
