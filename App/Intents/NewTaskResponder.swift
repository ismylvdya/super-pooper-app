import Foundation

/// Answers the New Task intent from the app model: the vault is read first (iOS may have launched the app for the
/// intent alone), then the task is created as the new task page creates it, and the answer is put into words.
@MainActor
enum NewTaskResponder {
    static func reply(to name: String, model: AppModel) async -> NewTaskReply {
        guard model.hasVault else { return .unavailable }
        await model.ensureLoaded()
        switch await model.createTask(named: name) {
        case .created(let created): return .created(name: created)
        case .rejected(let problem): return .rejected(reason: NoteNameProblemText.describe(problem, name: name))
        case .failed: return .failed
        }
    }
}
