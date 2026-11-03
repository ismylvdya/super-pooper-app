import SwiftUI

/// The sections of a habit page (also used by the new-habit draft, which has no history yet).
/// The description (the note body) sits right under the history; the tasks and habits it waits for or holds
/// back come after the statistics.
struct HabitSections: View {
    @Environment(AppModel.self) private var model
    let editor: TaskEditor

    var body: some View {
        // A task that simply repeats has no history grid or statistics to keep an eye on, unless the settings ask for them.
        let showsHistory = model.settings.habits.showsHistory(of: editor.task)
        if !editor.isDraft {
            if showsHistory { HabitHistorySection(habit: editor.task) }
            TaskNoteSection(taskName: editor.task.name, header: "habitPage.description", placeholder: "habitPage.description.placeholder")
            // Repeatable subtasks: they come up on the habit's days and are marked for each day.
            SubtasksSection(editor: editor)
            if showsHistory { HabitStatsSection(habit: editor.task) }
            TaskLinksSection(task: editor.task)
        }
        HabitOptionsSection(editor: editor)
        // High, estimate and feel, as on a task page: they sort the habit in the pool and show as its chips.
        TaskPropertiesSection(editor: editor)
        HabitGoalSection(editor: editor)
        // A repeatable subtask comes up on its parent's days: the parent's rule is written to it.
        if !model.isRepeatableSubtask(editor.task) { RecurrenceEditorSection(editor: editor) }
        HabitRemindersSection(editor: editor)
    }
}
