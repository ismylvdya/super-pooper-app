import SwiftUI

/// The sections of a habit page (also used by the new-habit draft, which has no history yet), from what is looked at and
/// changed most to what is set once: the history and statistics; when it comes up and rings; how it stands in the day; its
/// text and subtasks; what kind of note it is and how it looks; its goal.
struct HabitSections: View {
    @Environment(AppModel.self) private var model
    let editor: TaskEditor

    var body: some View {
        // A task that simply repeats has no history grid or statistics to keep an eye on, unless the settings ask for them.
        let showsHistory = model.settings.habits.showsHistory(of: editor.task)
        if !editor.isDraft, showsHistory {
            HabitHistorySection(habit: editor.task)
            HabitStatsSection(habit: editor.task)
        }
        // A repeatable subtask comes up on its parent's days: the parent's rule is written to it.
        if !model.isRepeatableSubtask(editor.task) { RecurrenceEditorSection(editor: editor) }
        HabitRemindersSection(editor: editor)
        HabitDaySection(editor: editor)
        if !editor.isDraft {
            TaskNoteSection(taskName: editor.task.name, header: "habitPage.description", placeholder: "habitPage.description.placeholder")
            // Repeatable subtasks: they come up on the habit's days and are marked for each day.
            SubtasksSection(editor: editor)
        }
        HabitOptionsSection(editor: editor)
        HabitGoalSection(editor: editor)
    }
}
