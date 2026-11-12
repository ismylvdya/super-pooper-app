import SwiftUI

/// What a "+" opens: one page for a new task, repeatable task or habit, with a Task / Repeatable task / Habit slider under
/// the name (`NoteKind`). The usual page
/// of the shown kind follows, with an empty name and the cursor already in it; switching the kind keeps the typed name
/// and what was set for each kind (`NewItemPage`). Nothing is written while it is open; Return in the name and Back do the same:
/// the page closes and the note of the shown kind is created with everything set here, with its banner. Another tab only hides
/// the page: the draft waits for the user to come back.
/// A name a note cannot take is shown right in the title; Return does not save it, and Back waits until it is changed.
/// A date typed into a task's name is blue: a tap on it sets the date and takes the words out; untapped, it stays words.
struct NewItemScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let seed: NewItemSeed
    /// The tab whose stack shows the page.
    var tab: AppTab?
    @State private var page: NewItemPage?

    var body: some View {
        let current = page ?? model.newItemPage(seed)
        let editor = TaskEditor.draft(Binding(get: { page?.draft ?? current.draft }, set: { page?.draft = $0 }))
        return PageScaffold(title: current.name.isEmpty ? L10n.string(Self.titleKey(current.kind)) : current.name,
                            titleView: AnyView(NewNoteNameField(placeholder: LocalizedStringKey(Self.titleKey(current.kind)),
                                                                name: Binding(get: { page?.name ?? "" }, set: { page?.name = $0 }),
                                                                problem: current.nameProblem(model.nameProblem(in:)),
                                                                suggestion: current.suggestion(model.detectDate(in: current.name)),
                                                                onAccept: { found in Haptics.play(.select); page?.accept(found) },
                                                                onReturn: saveOnReturn))) {
            NoteKindPicker(kinds: NoteKindPicker.order,
                           selection: Binding(get: { page?.noteKind ?? current.noteKind }, set: { page?.noteKind = $0 }))
            switch current.kind {
            case .task: TaskSections(editor: editor)
            case .habit: HabitSections(editor: editor)
            }
            Text(current.kind == .task ? "task.new.hint" : "habits.new.hint")
                .secondaryText(.hint)
        }
        .navigationBarBackButtonHidden(current.nameProblem(model.nameProblem(in:)) != nil)
        .onAppear { if page == nil { page = current } }
        .onDisappear(perform: leave)
    }

    private static func titleKey(_ kind: NewItemSeed.Kind) -> String {
        switch kind {
        case .task: "task.new.title"
        case .habit: "habits.new"
        }
    }

    /// A name the note can take closes the page, as Back does; `leave` creates the note.
    private func saveOnReturn() {
        guard let page, page.savedOnReturn(rules: model.nameProblem(in:)) != nil else { return }
        dismiss()
    }

    /// Another tab was chosen: the page is still in its stack, only hidden. Otherwise the page is left for good, and the
    /// draft goes once its note is created.
    private func leave() {
        if let tab, router.tab != tab { return }
        guard let page else { return }
        Task {
            if await model.create(from: page, unnamed: L10n.string("note.unnamed")) { self.page = nil }
        }
    }
}
