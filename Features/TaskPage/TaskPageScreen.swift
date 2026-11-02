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
                    ActionMenuButton(menu: .page(of: task), item: DayItem(listed: task), accessibilityID: "taskPage.more") {
                        handler.handle($0, taskName: task.name)
                    }
                }
            }
            .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
        } else if model.trashedNote(named: currentName) != nil {
            // The note was deleted while its page was open, or the page was opened by its link: it waits in the trash.
            EmptyStateView(icon: .trash, title: "taskPage.trashed.title", message: "taskPage.trashed.message")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ActionMenuButton(menu: .trashedPage, accessibilityID: "taskPage.more") {
                            handler.handle($0, taskName: currentName)
                        }
                    }
                }
        } else {
            EmptyStateView(icon: .problem, title: "taskPage.missing.title", message: "taskPage.missing.message")
                .task { await model.refreshTrash() }
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL, requestConfirmation: { pendingAction = $0 },
                          afterDelete: { dismiss() })
    }
}
