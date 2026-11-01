import Foundation

/// The app's answer to the New Task intent, ready for its dialog.
enum NewTaskReply: Equatable, Sendable {
    /// The task was written under this name.
    case created(name: String)
    /// The name cannot be used; why, in words. Nothing was written.
    case rejected(reason: String)
    /// The store could not write the note.
    case failed
    /// The app has no vault to write to (or the intent ran where the app's state is not).
    case unavailable
}
