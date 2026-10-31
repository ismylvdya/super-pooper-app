import Foundation

/// A note that does not exist yet: its fields, the changes that will be written when it is created,
/// its text and the subtasks created with it.
struct NoteDraft: Equatable, Sendable {
    var note: TaskNote
    private(set) var changes: [TaskEdit] = []
    var body = ""
    /// Names of the subtasks; empty entries are the "add a subtask" field and are skipped.
    var subtasks: [String] = []

    init(status: TaskStatus, changes: [TaskEdit] = []) {
        note = TaskNote(id: .unsaved, name: "", status: status)
        apply(changes)
    }

    /// A new task of this week.
    static var newTask: NoteDraft { NoteDraft(status: .thisWeek) }

    /// A new task of this week that is a subtask of `parent`.
    static func subtask(of parent: String) -> NoteDraft {
        NoteDraft(status: .thisWeek, changes: [.addProject(parent)])
    }

    /// A new habit, daily from `start`.
    static func newHabit(startingOn start: LocalDate, showInToday: Bool) -> NoteDraft {
        NoteDraft(status: .habit, changes: [.recurrence(RecurrenceDraft(start: start).rule), .showInToday(showInToday)])
    }

    mutating func apply(_ new: [TaskEdit]) {
        note = note.applying(new)
        changes += new
    }
}
