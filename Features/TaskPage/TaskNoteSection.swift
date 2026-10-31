import SwiftUI

/// The note body, edited as plain text; the model reads it and writes it shortly after typing stops. A text that could
/// not be read shows a problem instead of an empty field.
struct TaskNoteSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let taskName: String
    var header: LocalizedStringKey = "taskPage.note"
    var placeholder: LocalizedStringKey = "taskPage.note.placeholder"

    var body: some View {
        PlateSection(header: header, info: "info.taskPage.note") {
            if model.noteBodies[taskName]?.state == .unavailable {
                Label("taskPage.note.unavailable", systemImage: icons[.problem])
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.problem))
                    .accessibilityIdentifier("taskPage.note.unavailable")
            } else {
                // One line when empty, growing with the text.
                TextField(placeholder, text: text, axis: .vertical)
                    .font(tokens.font(.rowTitle))
                    .disabled(model.noteBodies[taskName]?.state != .editing)
                    .accessibilityIdentifier("taskPage.note")
            }
        }
        .task(id: taskName) { await model.openBody(of: taskName) }
        .onChange(of: taskName) { old, _ in model.closeBody(of: old) }
        .onDisappear { model.closeBody(of: taskName) }
    }

    private var text: Binding<String> {
        Binding(get: { model.noteBodies[taskName]?.text ?? "" }, set: { model.editBody($0, of: taskName) })
    }
}

/// The text of a task that is not created yet: kept in the draft and written with the note.
struct DraftNoteSection: View {
    @Environment(\.tokens) private var tokens
    @Binding var draft: NoteDraft

    var body: some View {
        PlateSection(header: "taskPage.note", info: "info.taskPage.note") {
            TextField("taskPage.note.placeholder", text: $draft.body, axis: .vertical)
                .font(tokens.font(.rowTitle))
                .accessibilityIdentifier("taskPage.note")
        }
    }
}
