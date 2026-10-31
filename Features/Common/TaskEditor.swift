import SwiftUI

/// What the sections of a task or habit page edit: an existing note (every change is written at once)
/// or a draft that becomes a note only when the page is left with a name.
@MainActor
struct TaskEditor {
    let task: TaskNote
    /// The draft itself (its text and subtasks), nil for an existing note.
    let draft: Binding<NoteDraft>?
    /// Changes decided from the note as it is when they are applied (a toggle tapped twice quickly flips twice).
    let edit: (@escaping (TaskNote) -> [TaskFieldChange]) -> Void

    var isDraft: Bool { draft != nil }

    func apply(_ changes: [TaskFieldChange]) { edit { _ in changes } }

    static func note(_ task: TaskNote, model: AppModel) -> TaskEditor {
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
