import SwiftUI

/// A new task (from the morning review) or habit (from the Habits tab): the usual page with an empty
/// name. Nothing is written while it is open; leaving the page with Back creates the note with
/// everything set here, and leaving it without a name creates nothing.
struct NewNoteScreen: View {
    enum Kind { case task, habit }

    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let kind: Kind
    @State private var draft: NoteDraft?
    @State private var name = ""

    var body: some View {
        let current = draft ?? initialDraft
        let editor = TaskEditor.draft(Binding(get: { draft ?? initialDraft }, set: { draft = $0 }))
        PageScaffold(title: name.isEmpty ? L10n.string(kind == .task ? "task.new.title" : "habits.new") : name) {
            NameField(text: $name, placeholder: kind == .task ? "taskPage.name.field" : "habitPage.name.placeholder")
            switch kind {
            case .task: TaskSections(editor: editor)
            case .habit: HabitSections(editor: editor)
            }
            Text(kind == .task ? "task.new.hint" : "habits.new.hint")
                .font(tokens.font(.hint))
                .foregroundStyle(tokens.color(.secondaryText))
        }
        .onAppear { if draft == nil { draft = current } }
        .onDisappear(perform: create)
    }

    private var initialDraft: NoteDraft {
        kind == .task ? NoteDraft(status: .thisWeek) : model.newHabitDraft()
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let draft else { return }
        self.draft = nil
        name = ""
        Task {
            if let created = await model.create(draft, named: trimmed) {
                model.banners.show(L10n.format("banner.created", created), style: .success)
            }
        }
    }
}
