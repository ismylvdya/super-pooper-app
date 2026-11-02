import SwiftUI

/// What a "+" opens: one page for a new task or a new habit, with a Task / Habit slider under the name. The usual page
/// of the shown kind follows, with an empty name and the cursor already in it; switching the kind keeps the typed name
/// and what was set for each kind (`NewItemPage`). Return in the name saves the note at once (`AppModel.createOnReturn`):
/// the keyboard goes and the page stays, now the note's own page, where every edit is written as on any task page.
/// Without Return nothing is written while it is open; leaving the page with Back creates the note of the shown kind
/// with everything set here. Another tab only hides the page: the draft waits for the user to come back.
/// A name a note cannot take is shown right in the title; Return does not save it, and Back waits until it is changed.
struct NewItemScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    let seed: NewItemSeed
    /// The tab whose stack shows the page.
    var tab: AppTab?
    @State private var page: NewItemPage?
    /// The note Return saved: the page is its own page from then on.
    @State private var saved: String?
    /// Return is saving the note: Back must not create a second one meanwhile.
    @State private var isSaving = false

    var body: some View {
        if let saved {
            TaskPageScreen(taskName: saved)
        } else {
            draftPage
        }
    }

    private var draftPage: some View {
        let current = page ?? model.newItemPage(kind: seed.kind)
        let editor = TaskEditor.draft(Binding(get: { page?.draft ?? current.draft }, set: { page?.draft = $0 }))
        return PageScaffold(title: current.name.isEmpty ? L10n.string(Self.titleKey(current.kind)) : current.name,
                            titleView: AnyView(NewNoteNameField(placeholder: LocalizedStringKey(Self.titleKey(current.kind)),
                                                                name: Binding(get: { page?.name ?? "" }, set: { page?.name = $0 }),
                                                                problem: current.nameProblem(model.nameProblem(in:)),
                                                                onReturn: saveOnReturn))) {
            Picker("newItem.kind", selection: Binding(get: { page?.kind ?? current.kind }, set: { page?.kind = $0 })) {
                Text("newItem.kind.task").tag(NewItemSeed.Kind.task)
                Text("newItem.kind.habit").tag(NewItemSeed.Kind.habit)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("newItem.kind")
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

    private func saveOnReturn() {
        guard let page, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            guard let name = await model.createOnReturn(from: page) else { return }
            self.page = nil
            saved = name
        }
    }

    /// Another tab was chosen: the page is still in its stack, only hidden. Otherwise the page is left for good, and the
    /// draft goes once its note is created.
    private func leave() {
        if let tab, router.tab != tab { return }
        guard let page, !isSaving else { return }
        Task {
            if await model.create(from: page, unnamed: L10n.string("note.unnamed")) { self.page = nil }
        }
    }
}
