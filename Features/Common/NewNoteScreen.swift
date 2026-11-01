import SwiftUI

/// A new task (from Soon or Today) or habit (from the Habits tab): the usual page with an empty
/// name, the cursor already in it. Return in the name saves the note at once (`AppModel.createOnReturn`): the keyboard
/// goes and the page stays, now the note's own page, where every edit is written as on any task page. Without Return
/// nothing is written while it is open; leaving the page with Back creates the note with everything set here (see
/// `NewNotePage`). Another tab only hides the page: the draft waits for the user to come back.
/// A name a note cannot take is shown right in the title; Return does not save it, and Back waits until it is changed.
struct NewNoteScreen: View {
    enum Kind { case task, habit }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    let kind: Kind
    /// The tab whose stack shows the page; nil in the Soon sheet, which no tab can hide.
    var tab: AppTab?
    @State private var page: NewNotePage?
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
        let current = page ?? NewNotePage(draft: initialDraft)
        let editor = TaskEditor.draft(Binding(get: { page?.draft ?? current.draft }, set: { page?.draft = $0 }))
        return PageScaffold(title: current.name.isEmpty ? L10n.string(titleKey) : current.name,
                            titleView: AnyView(NewNoteNameField(placeholder: LocalizedStringKey(titleKey),
                                                                name: Binding(get: { page?.name ?? "" }, set: { page?.name = $0 }),
                                                                problem: current.nameProblem(model.nameProblem(in:)),
                                                                onReturn: saveOnReturn))) {
            switch kind {
            case .task: TaskSections(editor: editor)
            case .habit: HabitSections(editor: editor)
            }
            Text(kind == .task ? "task.new.hint" : "habits.new.hint")
                .secondaryText(.hint)
        }
        .navigationBarBackButtonHidden(current.nameProblem(model.nameProblem(in:)) != nil)
        .onAppear { if page == nil { page = current } }
        .onDisappear(perform: leave)
    }

    private var titleKey: String { kind == .task ? "task.new.title" : "habits.new" }

    private var initialDraft: NoteDraft {
        kind == .task ? NoteDraft.newTask : model.newHabitDraft()
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
