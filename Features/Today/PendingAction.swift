import SwiftUI

/// An action waiting for its confirmation, with what the dialog says about the note.
struct PendingAction: Identifiable, Equatable {
    let action: ActionDefinition
    let taskName: String
    /// The title names the kind of note ("Delete habit?").
    let kind: NoteKind
    /// How many subtasks go along with the note.
    let subtasks: Int
    /// A task of the done folder (the Done list): the action goes by its id, as an active note may have the same name.
    var filed: TaskID?
    var id: String { "\(action.id.rawValue)|\(taskName)" }
}
