import SwiftUI

/// Everything about one task, editable: name (renames the file), status, High, date and time,
/// estimate, energy, pleasant, links to tasks and events, today's habit mark, note text.
struct TaskPageScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.icons) private var icons
    let taskName: String
    @State private var pendingAction: PendingAction?

    var body: some View {
        if let task = model.task(named: taskName) {
            let item = model.plan(at: model.clock.now).item(named: taskName)
            PageScaffold(title: task.name) {
                TaskTitleSection(task: task)
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
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}

/// The note name = file name; committing a new name renames the file.
struct TaskTitleSection: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    let task: TaskNote
    @State private var draft = ""

    var body: some View {
        PlateSection(header: "taskPage.name", info: "info.taskPage.name") {
            PlateRow(icon: .title, title: "taskPage.name.field") {
                TextField("taskPage.name.field", text: $draft)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("taskPage.name")
                    .submitLabel(.done)
                    .onSubmit(commit)
            }
        }
        .onAppear { draft = task.name }
        .onChange(of: task.name) { _, name in draft = name }
    }

    private func commit() {
        let newName = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != task.name else {
            draft = task.name
            return
        }
        Task {
            if await model.rename(task.name, to: newName) {
                if let index = router.path.lastIndex(of: .task(task.name)) { router.path[index] = .task(newName) }
                model.banners.show(L10n.format("banner.renamed", newName), style: .success)
            } else {
                draft = task.name
            }
        }
    }
}
