import SwiftUI

/// Everything about one note, editable. A task shows its status, date, estimate, links and text;
/// a habit shows its history, statistics, options, repeat rule and reminders.
/// The page keeps the current name itself, so renaming works wherever it was opened
/// (main stack, the Habits tab or the morning review sheet); after a delete it closes itself.
struct TaskPageScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.icons) private var icons
    @Environment(\.dismiss) private var dismiss
    let taskName: String
    @State private var renamedTo: String?
    @State private var pendingAction: PendingAction?

    private var currentName: String { renamedTo ?? taskName }

    var body: some View {
        if let task = model.task(named: currentName) {
            let editor = TaskEditor.note(task, model: model)
            PageScaffold(title: task.name, titleView: task.isHabit ? AnyView(HeaderNameField(task: task) { renamedTo = $0 }) : nil) {
                if task.isHabit {
                    HabitSections(editor: editor)
                } else {
                    TaskTitleSection(task: task) { renamedTo = $0 }
                    TaskSections(editor: editor)
                    TaskNoteSection(taskName: task.name)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ActionPopoverButton(menu: task.isHabit ? .habitPage : .taskPage, accessibilityID: "taskPage.more") {
                        handler.handle($0, taskName: task.name)
                    }
                }
            }
            .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
        } else {
            EmptyStateView(icon: .problem, title: "taskPage.missing.title", message: "taskPage.missing.message")
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL, requestConfirmation: { pendingAction = $0 },
                          afterDelete: { dismiss() })
    }
}

/// The sections of a task (also used by the new-task draft).
struct TaskSections: View {
    let editor: TaskEditor

    var body: some View {
        TaskPlanSection(editor: editor)
        TaskEventsSection(editor: editor)
        if !editor.isDraft { TaskLinksSection(task: editor.task) }
        TaskPropertiesSection(editor: editor)
    }
}

/// A habit's name edited right in the page title (as in the old Habits app): tap the title, type, Return.
struct HeaderNameField: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    let task: TaskNote
    let onRenamed: (String) -> Void
    @State private var draft = ""
    @FocusState private var isEditing: Bool
    @State private var isRenaming = false

    var body: some View {
        TextField("habitPage.name.placeholder", text: $draft, axis: .vertical)
            .multilineTextAlignment(.center)
            .submitLabel(.done)
            .focused($isEditing)
            .onSubmit { commit() }
            .onChange(of: draft) { _, value in
                // Return in a vertical field inserts a newline: treat it as "done".
                if value.contains("\n") {
                    draft = value.replacingOccurrences(of: "\n", with: "")
                    isEditing = false
                }
            }
            .onAppear { draft = task.name }
            .onChange(of: task.name) { _, name in if !isEditing { draft = name } }
            .onChange(of: isEditing) { _, editing in if !editing { commit() } }
            .accessibilityIdentifier("taskPage.name")
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
                model.banners.show(L10n.format("banner.renamed", newName), style: .success)
            } else {
                draft = task.name
            }
        }
    }
}

/// The note name = file name; committing a new name renames the file. The field is leading-aligned
/// so a trailing space stays visible while typing; spaces at the ends are trimmed only on commit.
struct TaskTitleSection: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    let task: TaskNote
    let onRenamed: (String) -> Void
    @State private var draft = ""
    @FocusState private var isEditingName: Bool
    /// Return and losing focus both commit; only one rename may run.
    @State private var isRenaming = false

    var body: some View {
        NameField(text: $draft, placeholder: task.isHabit ? "habitPage.name.placeholder" : "taskPage.name.field")
            .focused($isEditingName)
            .onSubmit(commit)
            .onAppear { draft = task.name }
            .onChange(of: task.name) { _, name in if !isEditingName { draft = name } }
            .onChange(of: isEditingName) { _, editing in if !editing { commit() } }
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
                model.banners.show(L10n.format("banner.renamed", newName), style: .success)
            } else {
                draft = task.name
            }
        }
    }
}

/// The name of a note as a plate with a full-width text field.
struct NameField: View {
    @Environment(\.tokens) private var tokens
    @Binding var text: String
    let placeholder: LocalizedStringKey

    var body: some View {
        PlateSection(header: "taskPage.name", info: "info.taskPage.name") {
            TextField(placeholder, text: $text)
                .font(tokens.font(.nameField))
                .submitLabel(.done)
                .accessibilityIdentifier("taskPage.name")
        }
    }
}
