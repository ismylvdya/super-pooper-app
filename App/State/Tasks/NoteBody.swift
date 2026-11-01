import Foundation

/// The text of a note open on its page. A text that could not be read (not downloaded, broken YAML, a failed read) is
/// unavailable, never empty: an empty field would write over the real text with the first keystroke.
struct NoteBody: Equatable {
    enum State: Equatable {
        case loading
        case unavailable
        case editing
    }

    private(set) var state: State
    private(set) var text: String
    /// The text as the note has it: read, or last written.
    private(set) var saved: String

    private init(state: State, text: String = "") {
        self.state = state
        self.text = text
        self.saved = text
    }

    static let loading = NoteBody(state: .loading)
    static let unavailable = NoteBody(state: .unavailable)
    static func read(_ text: String) -> NoteBody { NoteBody(state: .editing, text: text) }

    var hasUnsavedChanges: Bool { state == .editing && text != saved }

    /// Typing changes the text only once it was read.
    mutating func edit(_ text: String) -> Bool {
        guard state == .editing else { return false }
        self.text = text
        return true
    }

    mutating func markSaved(_ text: String) {
        guard state == .editing else { return }
        saved = text
    }
}
