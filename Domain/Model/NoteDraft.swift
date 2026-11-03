import Foundation

/// A note that does not exist yet: its fields, the changes that will be written when it is created,
/// its text and the subtasks created with it.
struct NoteDraft: Equatable, Sendable {
    var note: TaskItem
    private(set) var changes: [TaskEdit] = []
    var body = ""
    /// Names of the subtasks; empty entries are the "add a subtask" field and are skipped.
    var subtasks: [String] = []

    init(status: TaskStatus, changes: [TaskEdit] = []) {
        note = TaskItem(id: .unsaved, name: "", status: status)
        apply(changes)
    }

    /// A new task of this week.
    static var newTask: NoteDraft { NoteDraft(status: .thisWeek) }

    /// A new task of this week that is a subtask of `parent`.
    static func subtask(of parent: String) -> NoteDraft {
        NoteDraft(status: .thisWeek, changes: [.addProject(parent)])
    }

    /// A subtask of a habit or a repeatable task: a repeatable task with the parent's rule, in Today as the parent is.
    static func repeatableSubtask(of parent: TaskItem) -> NoteDraft {
        NoteDraft(status: .habit, changes: [.addProject(parent.name), .repeatable(true), .recurrence(parent.recurrence),
                                            .showInToday(parent.habit.showInToday)])
    }

    /// The subtask `parent` gets: repeatable under a habit or a repeatable task, a task of this week otherwise.
    static func subtask(of parent: TaskItem) -> NoteDraft {
        parent.isHabit ? repeatableSubtask(of: parent) : subtask(of: parent.name)
    }

    /// A new habit, daily from `start`, in its own `color` (`#RRGGBB`).
    static func newHabit(startingOn start: LocalDate, showInToday: Bool, color: String) -> NoteDraft {
        NoteDraft(status: .habit, changes: [.recurrence(RecurrenceDraft(start: start).rule), .showInToday(showInToday), .habitColor(color)])
    }

    mutating func apply(_ new: [TaskEdit]) {
        note = note.applying(new)
        changes += new
    }
}
