import SwiftUI

/// A new task (from This week or Today) or habit (from the Habits tab): the usual page with an empty
/// name, the cursor already in it; Return closes the keyboard and keeps the name. Nothing is written while
/// it is open; leaving the page with Back creates the note with everything set here. Without a name it is called "Unnamed" if anything was set, and nothing is
/// created if the page was left untouched.
struct NewNoteScreen: View {
    enum Kind { case task, habit }

    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let kind: Kind
    @State private var draft: NoteDraft?
    @State private var untouched: NoteDraft?
    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        let current = draft ?? initialDraft
        let editor = TaskEditor.draft(Binding(get: { draft ?? initialDraft }, set: { draft = $0 }))
        let placeholder: LocalizedStringKey = kind == .task ? "task.new.title" : "habits.new"
        // The name is typed right in the title, as on the note's page.
        PageScaffold(title: name.isEmpty ? L10n.string(kind == .task ? "task.new.title" : "habits.new") : name,
                     titleView: AnyView(TextField(placeholder, text: $name, axis: .vertical)
                        .multilineTextAlignment(.center)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .onChange(of: name) { _, value in
                            // Return in a vertical field inserts a newline: it means "done".
                            guard value.contains("\n") else { return }
                            name = value.replacingOccurrences(of: "\n", with: "")
                            isNameFocused = false
                        }
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
        .task { isNameFocused = true }
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
