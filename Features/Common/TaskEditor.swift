import SwiftUI

/// What the sections of a task or habit page edit: an existing note (every change is written at once)
/// or a draft that becomes a note only when the page is left with a name.
@MainActor
struct TaskEditor {
    let task: TaskItem
    /// The draft itself (its text and subtasks), nil for an existing note.
    let draft: Binding<NoteDraft>?
    /// Changes decided from the note as it is when they are applied (a toggle tapped twice quickly flips twice).
    let edit: (@escaping (TaskItem) -> [TaskEdit]) -> Void

    var isDraft: Bool { draft != nil }

    func apply(_ changes: [TaskEdit]) { edit { _ in changes } }

    /// A status picked for the note, by the one rule of status changes (`TaskMarking`).
    func setStatus(_ status: TaskStatus, today: LocalDate) {
        edit { note in TaskMarking(today: today).changes(setting: status, on: note) }
    }

    static func note(_ task: TaskItem, model: AppModel) -> TaskEditor {
        TaskEditor(task: task, draft: nil) { changes in
            Task { await model.edit(task.name, changes) }
        }
    }

    static func draft(_ draft: Binding<NoteDraft>) -> TaskEditor {
        TaskEditor(task: draft.wrappedValue.note, draft: draft) { changes in
            draft.wrappedValue.apply(changes(draft.wrappedValue.note))
        }
    }
}
