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

/// A note that does not exist yet: its fields, the changes that will be written when it is created,
/// its text and the subtasks created with it.
struct NoteDraft: Equatable {
    var note: TaskNote
    private(set) var changes: [TaskFieldChange] = []
    var body = ""
    /// Names of the subtasks; empty entries are the "add a subtask" field and are skipped.
    var subtasks: [String] = []

    init(status: TaskStatus, changes: [TaskFieldChange] = []) {
        note = TaskNote(name: "", relativePath: "", status: status)
        apply(changes)
    }

    mutating func apply(_ new: [TaskFieldChange]) {
        note = note.applying(new)
        changes += new
    }
}
