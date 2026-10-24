import SwiftUI

/// A new task (from the morning review) or habit (from the Habits tab): the usual page with an empty
/// name. Nothing is written while it is open; leaving the page with Back creates the note with
/// everything set here. Without a name it is called "Unnamed" if anything was set, and nothing is
/// created if the page was left untouched.
struct NewNoteScreen: View {
    enum Kind { case task, habit }

    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let kind: Kind
    @State private var draft: NoteDraft?
    @State private var untouched: NoteDraft?
    @State private var name = ""

    var body: some View {
        let current = draft ?? initialDraft
        let editor = TaskEditor.draft(Binding(get: { draft ?? initialDraft }, set: { draft = $0 }))
        let placeholder: LocalizedStringKey = kind == .task ? "task.new.title" : "habits.new"
        // The name is typed right in the title, as on the note's page.
        PageScaffold(title: name.isEmpty ? L10n.string(kind == .task ? "task.new.title" : "habits.new") : name,
                     titleView: AnyView(TextField(placeholder, text: $name, axis: .vertical)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("taskPage.name"))) {
            switch kind {
            case .task: TaskSections(editor: editor)
            case .habit: HabitSections(editor: editor)
            }
            Text(kind == .task ? "task.new.hint" : "habits.new.hint")
                .font(tokens.font(.hint))
                .foregroundStyle(tokens.color(.secondaryText))
        }
        .onAppear {
            if draft == nil { draft = current }
            if untouched == nil { untouched = current }
        }
        .onDisappear(perform: create)
    }

    private var initialDraft: NoteDraft {
        kind == .task ? NoteDraft(status: .thisWeek) : model.newHabitDraft()
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let draft, !trimmed.isEmpty || draft != untouched else { return }
        let finalName = trimmed.isEmpty ? L10n.string("note.unnamed") : trimmed
        self.draft = nil
        name = ""
        Task {
            if let created = await model.create(draft, named: finalName) {
                model.banners.show(L10n.format("banner.created", created), style: .success)
            }
        }
    }
}
