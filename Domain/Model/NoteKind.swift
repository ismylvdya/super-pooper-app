import Foundation

/// What a note is to the user: a task, a habit kept track of, or a task that simply repeats (a habit note marked
/// repeatable). Texts that name the note say which (the delete confirmation).
enum NoteKind: String, CaseIterable, Sendable {
    case task
    case habit
    case repeatable
}

extension TaskItem {
    var kind: NoteKind {
        guard isHabit else { return .task }
        return habit.repeatable ? .repeatable : .habit
    }
}
