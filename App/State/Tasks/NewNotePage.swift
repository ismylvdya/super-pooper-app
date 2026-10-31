import Foundation

/// The new task or habit page as it is being filled in: the draft, the name typed in the title and what leaving the
/// page creates. Nothing is written while the page is open; the draft stays until the note is created.
struct NewNotePage: Equatable {
    var draft: NoteDraft
    var name = ""
    private let untouched: NoteDraft

    init(draft: NoteDraft) {
        self.draft = draft
        untouched = draft
    }

    /// What is wrong with the typed name by the store's `rules`; an empty name is fine (the note is called "Unnamed").
    func nameProblem(_ rules: (String) -> NoteNameProblem?) -> NoteNameProblem? {
        trimmedName.isEmpty ? nil : rules(trimmedName)
    }

    /// The note leaving the page creates: none for a page left untouched or with a name a note cannot take.
    /// `unnamed`: the name of a note whose name was left empty.
    func creation(unnamed: String, rules: (String) -> NoteNameProblem?) -> (draft: NoteDraft, name: String)? {
        guard nameProblem(rules) == nil, !trimmedName.isEmpty || draft != untouched else { return nil }
        return (draft, trimmedName.isEmpty ? unnamed : trimmedName)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
}
