import Foundation

/// A note that does not exist yet: its fields, the changes that will be written when it is created,
/// its text and the subtasks created with it.
struct NoteDraft: Equatable, Sendable {
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
