import SwiftUI

/// The sections of a habit page (also used by the new-habit draft, which has no history yet).
/// The description (the note body) sits right under the history.
struct HabitSections: View {
    let editor: TaskEditor

    var body: some View {
        if !editor.isDraft {
            HabitHistorySection(habit: editor.task)
            TaskNoteSection(taskName: editor.task.name, header: "habitPage.description", placeholder: "habitPage.description.placeholder")
            HabitStatsSection(habit: editor.task)
        }
        HabitOptionsSection(editor: editor)
        HabitGoalSection(editor: editor)
        RecurrenceEditorSection(editor: editor)
        HabitRemindersSection(editor: editor)
    }
}
