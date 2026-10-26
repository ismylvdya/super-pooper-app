import SwiftUI

/// Routes a chosen registry action: navigation stays in the UI layer, data changes go to the
/// app model, confirmed actions wait for the dialog.
@MainActor
struct TaskActionHandler {
    let model: AppModel
    let router: Router
    let openURL: OpenURLAction
    let requestConfirmation: (PendingAction) -> Void
    /// The page showing the task closes itself after a delete.
    var afterDelete: (() -> Void)?

    func handle(_ action: ActionDefinition, taskName: String) {
        if action.needsConfirmation {
            requestConfirmation(PendingAction(action: action, taskName: taskName))
            return
        }
        run(action, taskName: taskName)
    }

    func run(_ action: ActionDefinition, taskName: String) {
        switch action.id {
        case .open:
            router.open(.task(taskName))
        case .openInObsidian:
            Task {
                if let url = await model.obsidianURL(for: taskName) { openURL(url) }
            }
        case .delete:
            Task {
                await model.perform(.delete, on: taskName)
                if model.task(named: taskName) == nil { afterDelete?() }
            }
        default:
            Task { await model.perform(action.id, on: taskName) }
        }
    }
}
