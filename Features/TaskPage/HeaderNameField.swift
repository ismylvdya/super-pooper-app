import SwiftUI

/// A habit's name edited right in the page title (as in the old Habits app): tap the title, type, Return.
struct HeaderNameField: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    let task: TaskItem
    let onRenamed: (String) -> Void
    @State private var draft = ""
    @FocusState private var isEditing: Bool
    @State private var isRenaming = false

    var body: some View {
        // A habit's name is in its color, as in the Habits list.
        TitleTextField(placeholder: task.isHabit ? "habitPage.name.placeholder" : "taskPage.name.field", text: $draft,
                       color: task.isHabit ? tokens.habitNameColor(task) : tokens.color(.primaryText), isFocused: $isEditing)
            .onSubmit { commit() }
            .onAppear { draft = task.name }
            .onChange(of: task.name) { _, name in if !isEditing { draft = name } }
            .onChange(of: isEditing) { _, editing in if !editing { commit() } }
    }

    private func commit() {
        guard !isRenaming else { return }
        let newName = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != task.name else {
            draft = task.name
            return
        }
        isRenaming = true
        Task {
            defer { isRenaming = false }
            if await model.rename(task.name, to: newName) {
                onRenamed(newName)
                if let index = router.path.lastIndex(of: .task(task.name)) { router.path[index] = .task(newName) }
            } else {
                draft = task.name
            }
        }
    }
}
