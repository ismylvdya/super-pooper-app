import SwiftUI

/// An action waiting for its confirmation, with what the dialog says about the note.
struct PendingAction: Identifiable, Equatable {
    let action: ActionDefinition
    let taskName: String
    /// The title names the kind of note ("Delete habit?").
    let kind: NoteKind
    /// How many subtasks go along with the note.
    let subtasks: Int
    var id: String { "\(action.id.rawValue)|\(taskName)" }
}
