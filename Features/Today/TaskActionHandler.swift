import SwiftUI

/// Routes a chosen registry action: navigation stays in the UI layer, data changes go to the app model, confirmed
/// actions wait for the dialog. An action that can be taken back runs at once and the banner offers Undo instead.
@MainActor
struct TaskActionHandler {
    let model: AppModel
    let router: Router
    let openURL: OpenURLAction
    let requestConfirmation: (PendingAction) -> Void
    /// The page showing the task closes itself after a delete.
    var afterDelete: (() -> Void)?
    /// The day the pool shows (nil: today): Unworm takes the task off that day's worm.
    var shownDay: LocalDate?
    /// Select from a row's menu starts the pool's Select mode with that row picked.
    var startSelection: ((String) -> Void)?

    func handle(_ action: ActionDefinition, taskName: String) {
        if model.needsConfirmation(action) {
            requestConfirmation(PendingAction(action: action, taskName: taskName, kind: model.task(named: taskName)?.kind ?? .task,
                                              subtasks: model.subtasksGoingAlong(with: taskName, action: action.id)))
            return
        }
        run(action, taskName: taskName)
    }

    /// An action on a task of the done folder (the Done list).
    func handle(_ action: ActionDefinition, filed task: TaskItem) {
        if model.needsConfirmation(action) {
            requestConfirmation(PendingAction(action: action, taskName: task.name, kind: task.kind, subtasks: 0, filed: task.id))
            return
        }
        Task { await model.performOfferingUndo(action, onFiled: task.id) }
    }

    /// A confirmed action.
    func run(_ pending: PendingAction) {
        if let filed = pending.filed {
            Task { await model.perform(pending.action.id, onFiled: filed) }
        } else {
            run(pending.action, taskName: pending.taskName)
        }
    }

    func run(_ action: ActionDefinition, taskName: String) {
        switch action.id {
        case .open:
            router.open(.task(taskName))
        case .openInObsidian:
            Task {
                if let url = await model.externalURL(for: taskName) { openURL(url) }
            }
        case .restoreFromTrash:
            Task { await model.restoreFromTrash(named: taskName) }
        case .select:
            startSelection?(taskName)
        case .unworm:
            model.unworm([taskName], on: shownDay)
        case .delete:
            Task {
                await model.performOfferingUndo(action, on: taskName)
                if model.task(named: taskName) == nil { afterDelete?() }
            }
        default:
            Task { await model.performOfferingUndo(action, on: taskName) }
        }
    }
}
