import SwiftUI

/// The sections of a task (also used by the new-item page): the three chip rows under the name, subtasks, the
/// text, then everything else.
struct TaskSections: View {
    let editor: TaskEditor

    var body: some View {
        TaskChipRows(editor: editor)
        SubtasksSection(editor: editor)
        if let draft = editor.draft {
            DraftNoteSection(draft: draft)
        } else {
            TaskNoteSection(taskName: editor.task.name)
        }
        TaskEventsSection(editor: editor)
        if !editor.isDraft { TaskLinksSection(task: editor.task) }
        TaskPropertiesSection(editor: editor)
    }
}
