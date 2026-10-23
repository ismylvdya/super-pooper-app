import SwiftUI

/// Everything about one task, editable: name (renames the file), status, High, date and time,
/// estimate, energy, pleasant, links to tasks and events, today's habit mark, note text.
/// The page keeps the current name itself, so renaming works wherever it was opened
/// (main stack or the morning review sheet); after a delete it closes itself.
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
            let item = model.plan(at: model.clock.now).item(named: currentName)
            PageScaffold(title: task.name) {
                TaskTitleSection(task: task) { renamedTo = $0 }
                TaskPropertiesSection(task: task)
                if task.isRecurring { TaskRecurrenceSection(task: task, item: item) }
                TaskLinksSection(task: task)
                TaskEventsSection(task: task)
                TaskNoteSection(taskName: task.name)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ActionMenuContent(menu: .taskPage, item: nil) { handler.handle($0, taskName: task.name) }
                    } label: {
                        Image(systemName: icons[.more])
                    }
                    .accessibilityLabel(Text("taskPage.more"))
                    .accessibilityIdentifier("taskPage.more")
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

/// The note name = file name; committing a new name renames the file.
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
        PlateSection(header: "taskPage.name", info: "info.taskPage.name") {
            PlateRow(icon: .title, title: "taskPage.name.field") {
                TextField("taskPage.name.field", text: $draft)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("taskPage.name")
                    .focused($isEditingName)
                    .submitLabel(.done)
                    .onSubmit(commit)
            }
        }
        .onAppear {
            draft = task.name
            if router.focusNameOf == task.name {
                router.focusNameOf = nil
                draft = ""
                isEditingName = true
            }
        }
        .onChange(of: task.name) { _, name in draft = name }
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
