import Foundation

/// The words of an action's confirmation: its message about the note and, under it, how many subtasks go along.
enum ConfirmationText {
    static func message(_ pending: PendingAction) -> String {
        let message = L10n.format(pending.action.confirmMessage ?? "", pending.taskName)
        guard pending.subtasks > 0, let subtasks = pending.action.confirmSubtasks else { return message }
        return message + "\n\n" + L10n.format(subtasks, pending.subtasks)
    }
}
