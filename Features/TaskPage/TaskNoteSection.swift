import SwiftUI

/// The note body, edited as plain text and saved shortly after typing stops.
struct TaskNoteSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
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
                    .frame(minHeight: 160)
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
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                await model.setBody(value, of: taskName)
                self.loaded = value
            }
        }
        .onDisappear {
            guard let loaded, text != loaded else { return }
            let value = text
            Task { await model.setBody(value, of: taskName) }
        }
    }
}
