import SwiftUI

extension View {
    /// Asks for the name first: the note is created only when the name is confirmed, then `onCreated` gets it.
    func newTaskPrompt(isPresented: Binding<Bool>, onCreated: @escaping (String) -> Void) -> some View {
        modifier(NewTaskPrompt(isPresented: isPresented, onCreated: onCreated))
    }
}

private struct NewTaskPrompt: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var isPresented: Bool
    let onCreated: (String) -> Void
    @State private var name = ""

    func body(content: Content) -> some View {
        content.alert("task.new.title", isPresented: $isPresented) {
            TextField("task.new.placeholder", text: $name)
            Button("task.new.create") { create() }
            Button("common.cancel", role: .cancel) { name = "" }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = ""
        guard !trimmed.isEmpty else { return }
        Task {
            guard let created = await model.createTask(named: trimmed) else { return }
            onCreated(created)
        }
    }
}
