import SwiftUI

/// What the sections of a task or habit page edit: an existing note (every change is written at once)
/// or a draft that becomes a note only when the page is left with a name.
@MainActor
struct TaskEditor {
    let task: TaskNote
    let isDraft: Bool
    let apply: ([TaskFieldChange]) -> Void

    static func note(_ task: TaskNote, model: AppModel) -> TaskEditor {
        TaskEditor(task: task, isDraft: false) { changes in
            Task { await model.update(task.name, changes) }
        }
    }

    static func draft(_ draft: Binding<NoteDraft>) -> TaskEditor {
        TaskEditor(task: draft.wrappedValue.note, isDraft: true) { changes in
            draft.wrappedValue.apply(changes)
        }
    }
}

/// A note that does not exist yet: its fields and the changes that will be written when it is created.
struct NoteDraft: Equatable {
    var note: TaskNote
    private(set) var changes: [TaskFieldChange] = []

    init(status: TaskStatus, changes: [TaskFieldChange] = []) {
        note = TaskNote(name: "", relativePath: "", status: status)
        apply(changes)
    }

    mutating func apply(_ new: [TaskFieldChange]) {
        note = note.applying(new)
        changes += new
    }
}
