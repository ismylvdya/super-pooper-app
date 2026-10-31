import SwiftUI

/// A new task (from This week or Today) or habit (from the Habits tab): the usual page with an empty
/// name, the cursor already in it. Nothing is written while it is open; leaving the page with Back creates the note with
/// everything set here (see `NewNotePage`). Another tab only hides the page: the draft waits for the user to come back.
/// A name a note cannot take is shown right in the title, and Back waits until it is changed.
struct NewNoteScreen: View {
    enum Kind { case task, habit }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    let kind: Kind
    /// The tab whose stack shows the page; nil in the This week sheet, which no tab can hide.
    var tab: AppTab?
    @State private var page: NewNotePage?

    var body: some View {
        let current = page ?? NewNotePage(draft: initialDraft)
        let editor = TaskEditor.draft(Binding(get: { page?.draft ?? current.draft }, set: { page?.draft = $0 }))
        PageScaffold(title: current.name.isEmpty ? L10n.string(titleKey) : current.name,
                     titleView: AnyView(NewNoteNameField(placeholder: LocalizedStringKey(titleKey),
                                                         name: Binding(get: { page?.name ?? "" }, set: { page?.name = $0 }),
                                                         problem: current.nameProblem))) {
            switch kind {
            case .task: TaskSections(editor: editor)
            case .habit: HabitSections(editor: editor)
            }
            Text(kind == .task ? "task.new.hint" : "habits.new.hint")
                .font(tokens.font(.hint))
                .foregroundStyle(tokens.color(.secondaryText))
        }
        .navigationBarBackButtonHidden(current.nameProblem != nil)
        .onAppear { if page == nil { page = current } }
        .onDisappear(perform: leave)
    }

    private var titleKey: String { kind == .task ? "task.new.title" : "habits.new" }

    private var initialDraft: NoteDraft {
        kind == .task ? NoteDraft(status: .thisWeek) : model.newHabitDraft()
    }

    /// Another tab was chosen: the page is still in its stack, only hidden. Otherwise the page is left for good.
    private func leave() {
        if let tab, router.tab != tab { return }
        guard let page else { return }
        if let problem = page.nameProblem {
            model.banners.show(NoteNameProblemText.describe(problem, name: page.name), style: .problem)
            return
        }
        guard let creation = page.creation(unnamed: L10n.string("note.unnamed")) else { return }
        Task {
            guard let created = await model.create(creation.draft, named: creation.name) else { return }
            self.page = nil
            model.banners.show(L10n.format("banner.created", created), style: .success)
        }
    }
}
