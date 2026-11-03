import Foundation

/// The new-item page as it is being filled in: the kind shown (a task or a habit), the name typed in the title, a draft
/// per kind, what Return in the name saves at once and what leaving the page creates. Switching the kind keeps the name
/// and both drafts, so switching back finds what was set there; only the shown kind is created.
struct NewItemPage: Equatable {
    var kind: NewItemSeed.Kind
    var name = ""
    private var taskDraft: NoteDraft
    private var habitDraft: NoteDraft
    private let untouchedTask: NoteDraft
    private let untouchedHabit: NoteDraft

    init(kind: NewItemSeed.Kind, taskDraft: NoteDraft, habitDraft: NoteDraft) {
        self.kind = kind
        self.taskDraft = taskDraft
        self.habitDraft = habitDraft
        untouchedTask = taskDraft
        untouchedHabit = habitDraft
    }

    /// The shown kind's draft.
    var draft: NoteDraft {
        get { kind == .task ? taskDraft : habitDraft }
        set {
            switch kind {
            case .task: taskDraft = newValue
            case .habit: habitDraft = newValue
            }
        }
    }

    /// The date found in the name, offered in blue while it is a task's and not already its date.
    func suggestion(_ detected: DetectedDate?) -> DetectedDate? {
        guard kind == .task, let detected, draft.note.due != detected.due else { return nil }
        return detected
    }

    /// The blue date was tapped: it becomes the task's date and its words leave the name, unless they are the whole
    /// name (a task is not left without one).
    mutating func accept(_ detected: DetectedDate) {
        draft.apply([.due(detected.due)])
        let rest = DateDetector.removing(detected, from: name)
        if !rest.isEmpty { name = rest }
    }

    /// A task named outside the app's pages (the New Task intent) has no blue suggestion: a date in its name is taken
    /// at once; without one the task waits in the Inbox.
    mutating func takeNamedDate(_ detected: DetectedDate?) {
        if let detected {
            accept(detected)
        } else {
            draft = NoteDraft(status: .inbox, changes: draft.changes)
        }
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

    /// What Return in the name saves at once: the note under the typed name; nothing for an empty name (Return only
    /// closes the keyboard) or a name a note cannot take (the title already says why).
    func savedOnReturn(rules: (String) -> NoteNameProblem?) -> (draft: NoteDraft, name: String)? {
        guard !trimmedName.isEmpty, nameProblem(rules) == nil else { return nil }
        return (draft, trimmedName)
    }

    private var untouched: NoteDraft { kind == .task ? untouchedTask : untouchedHabit }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
}
