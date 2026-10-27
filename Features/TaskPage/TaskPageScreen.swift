import SwiftUI

/// Everything about one note, editable. A task shows its status, date, estimate, links and text;
/// a habit shows its history, statistics, options, repeat rule and reminders.
/// The page keeps the current name itself, so renaming works wherever it was opened
/// (main stack, the Habits tab or the morning review sheet); after a delete it closes itself.
struct TaskPageScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    let taskName: String
    @State private var renamedTo: String?
    @State private var pendingAction: PendingAction?

    private var currentName: String { renamedTo ?? taskName }

    var body: some View {
        if let task = model.task(named: currentName) {
            let editor = TaskEditor.note(task, model: model)
            PageScaffold(title: task.name, titleView: AnyView(HeaderNameField(task: task) { renamedTo = $0 })) {
                if task.isHabit {
                    HabitSections(editor: editor)
                } else {
                    TaskSections(editor: editor)
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

/// The sections of a task (also used by the new-task draft): the quick chips under the name, subtasks, the
/// text, then everything else.
struct TaskSections: View {
    let editor: TaskEditor

    var body: some View {
        TaskQuickChips(editor: editor)
        SubtasksSection(editor: editor)
        if let draft = editor.draft {
            DraftNoteSection(draft: draft)
        } else {
            TaskNoteSection(taskName: editor.task.name)
        }
        TaskEventsSection(editor: editor)
        if !editor.isDraft { TaskLinksSection(task: editor.task) }
        TaskPropertiesSection(editor: editor)
    }
}

/// A habit's name edited right in the page title (as in the old Habits app): tap the title, type, Return.
struct HeaderNameField: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    let task: TaskNote
    let onRenamed: (String) -> Void
    @State private var draft = ""
    @FocusState private var isEditing: Bool
    @State private var isRenaming = false

    var body: some View {
        TextField(task.isHabit ? "habitPage.name.placeholder" : "taskPage.name.field", text: $draft, axis: .vertical)
            .multilineTextAlignment(.center)
            // A habit's name is in its color, as in the Habits list.
            .foregroundStyle(task.isHabit ? tokens.habitNameColor(task) : tokens.color(.primaryText))
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
