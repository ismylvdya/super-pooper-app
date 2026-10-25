import SwiftUI

/// The note body, edited as plain text and saved shortly after typing stops.
struct TaskNoteSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let taskName: String
    var header: LocalizedStringKey = "taskPage.note"
    /// One line when empty, growing with the text (habit descriptions).
    var isCompact = false
    @State private var text = ""
    @State private var loaded: String?
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        PlateSection(header: header, info: "info.taskPage.note") {
            if isCompact {
                TextField("habitPage.description.placeholder", text: $text, axis: .vertical)
                    .font(tokens.font(.rowTitle))
            } else {
                TextEditor(text: $text)
                    .font(tokens.font(.noteEditor))
                    .frame(minHeight: tokens.size(.noteEditorMinHeight))
                    .scrollContentBackground(.hidden)
            }
        }
        .task(id: taskName) {
            let body = await model.body(of: taskName) ?? ""
            loaded = body
            text = body
        }
        .onChange(of: text) { _, value in
            guard let loaded, value != loaded else { return }
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(for: .seconds(rules.editing.noteSaveDelaySeconds))
                guard !Task.isCancelled else { return }
                await model.setBody(value, of: taskName)
                self.loaded = value
            }
        }
        .onDisappear {
            saveTask?.cancel()
            guard let loaded, text != loaded else { return }
            let value = text
            Task { await model.setBody(value, of: taskName) }
        }
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
                .lineLimit(3...)
                .accessibilityIdentifier("taskPage.note")
        }
    }
}
