import SwiftUI

/// The sections of a habit or repeatable task page (also used by the new-habit draft, which has no history yet): history,
/// subtasks, text and reminders; its kind; when it repeats; how it stands in the pool; the rest; statistics at the very bottom. History
/// and statistics are a habit's: a task that simply repeats has none unless the settings ask for them.
struct HabitSections: View {
    @Environment(AppModel.self) private var model
    let editor: TaskEditor

    var body: some View {
        let showsHistory = !editor.isDraft && model.settings.habits.showsHistory(of: editor.task)
        if showsHistory { HabitHistorySection(habit: editor.task) }
        ParentTaskSection(editor: editor)
        // Repeatable subtasks: they come up on the habit's days and are marked for each day.
        SubtasksSection(editor: editor, header: editor.task.habit.repeatable ? "habitPage.subtasks.repeatable" : "habitPage.subhabits")
        if let draft = editor.draft {
            DraftNoteSection(draft: draft, header: "habitPage.description")
        } else {
            TaskNoteSection(taskName: editor.task.name, header: "habitPage.description", placeholder: "habitPage.description.placeholder")
        }
        HabitRemindersSection(editor: editor)
        HabitKindSection(editor: editor)
        // A repeatable subtask comes up on its parent's days: the parent's rule is written to it.
        if !model.isRepeatableSubtask(editor.task) { RecurrenceEditorSection(editor: editor) }
        HabitDaySection(editor: editor)
        HabitOptionsSection(editor: editor)
        if showsHistory { HabitStatsSection(habit: editor.task) }
    }
}

/// What the note is: a habit to keep track of or a task that simply repeats.
private struct HabitKindSection: View {
    let editor: TaskEditor

    var body: some View {
        PlateSection(header: nil) {
            PlateRow(icon: .recurrence, title: "habitPage.kind", info: "info.habitPage.repeatable") {}
            Picker("habitPage.kind", selection: Binding(get: { editor.task.habit.repeatable }, set: { editor.apply([.repeatable($0)]) })) {
                Text("habitPage.kind.habit").tag(false)
                Text("habitPage.kind.repeatable").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("habitPage.kind")
        }
    }
}
