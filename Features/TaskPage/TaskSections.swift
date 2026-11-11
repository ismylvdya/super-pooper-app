import SwiftUI

/// The sections of a task (also used by the new-item page), the chip rows under the name, the parent task, subtasks, the text, the rest of
/// its properties.
struct TaskSections: View {
    let editor: TaskEditor

    var body: some View {
        TaskChipRows(editor: editor)
        ParentTaskSection(editor: editor)
        SubtasksSection(editor: editor)
        if let draft = editor.draft {
            DraftNoteSection(draft: draft)
        } else {
            TaskNoteSection(taskName: editor.task.name)
        }
        TaskPropertiesSection(editor: editor)
    }
}
