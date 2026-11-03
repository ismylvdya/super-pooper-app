import SwiftUI

/// The sections of a task (also used by the new-item page), from what is changed most: the three chip rows under the name,
/// its status and estimate, subtasks, the text.
struct TaskSections: View {
    let editor: TaskEditor

    var body: some View {
        TaskChipRows(editor: editor)
        TaskPropertiesSection(editor: editor)
        SubtasksSection(editor: editor)
        if let draft = editor.draft {
            DraftNoteSection(draft: draft)
        } else {
            TaskNoteSection(taskName: editor.task.name)
        }
    }
}
