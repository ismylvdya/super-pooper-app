import Foundation

/// What became of a task named outside the new task page (the New Task intent).
enum NamedTaskCreation: Equatable {
    /// The note was written under this name (a taken name gets a number).
    case created(String)
    /// The name cannot be used; nothing was written.
    case rejected(NoteNameProblem)
    /// The store could not write the note (the app's banner says why).
    case failed
}
