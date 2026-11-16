import Foundation

/// The new-item page as it is being filled in: the kind shown (a task or a habit), the name typed in the title, a draft
/// per kind, what Return in the name saves at once and what leaving the page creates. Switching the kind keeps the name
/// and both drafts, so switching back finds what was set there; only the shown kind is created. A "+" dropped on a
/// timeline presets that moment (a task's date and time, a habit's reminder time); dropped in the pool, the spot the
/// note takes there once made.
struct NewItemPage: Equatable {
    var kind: NewItemSeed.Kind
    var name = ""
    let placement: NewItemPlacement?
    private var taskDraft: NoteDraft
    private var habitDraft: NoteDraft
    private let untouchedTask: NoteDraft
    private let untouchedHabit: NoteDraft

    /// `today`: a "+" dropped in today's pool puts the task in it rather than dating it.
    init(seed: NewItemSeed, taskDraft: NoteDraft, habitDraft: NoteDraft, today: LocalDate? = nil) {
        var taskDraft = taskDraft
        var habitDraft = habitDraft
        if let placement = seed.placement {
            taskDraft.apply(placement.presets(.task, today: today))
            habitDraft.apply(placement.presets(.habit))
        }
        if let estimate = seed.estimate { taskDraft.apply([.timeEstimate(estimate)]) }
        kind = seed.kind
        placement = seed.placement
        self.taskDraft = taskDraft
        self.habitDraft = habitDraft
        untouchedTask = taskDraft
        untouchedHabit = habitDraft
    }

    init(kind: NewItemSeed.Kind, taskDraft: NoteDraft, habitDraft: NoteDraft) {
        self.init(seed: NewItemSeed(kind: kind), taskDraft: taskDraft, habitDraft: habitDraft)
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

    /// The kind as the page's one switch says it: a task, a repeatable task or a habit. The last two are both a habit's
    /// draft, told apart by `repeatable`.
    var noteKind: NoteKind {
        get { kind == .task ? .task : (habitDraft.note.habit.repeatable ? .repeatable : .habit) }
        set {
            kind = newValue == .task ? .task : .habit
            if newValue != .task, habitDraft.note.habit.repeatable != (newValue == .repeatable) {
                habitDraft.apply([.repeatable(newValue == .repeatable)])
            }
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

    /// What Return in the name closes the page with: the note under the typed name; nothing for an empty name (Return only
    /// closes the keyboard) or a name a note cannot take (the title already says why).
    func savedOnReturn(rules: (String) -> NoteNameProblem?) -> (draft: NoteDraft, name: String)? {
        guard !trimmedName.isEmpty, nameProblem(rules) == nil else { return nil }
        return (draft, trimmedName)
    }

    private var untouched: NoteDraft { kind == .task ? untouchedTask : untouchedHabit }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
}
