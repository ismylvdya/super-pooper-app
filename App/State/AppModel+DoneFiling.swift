import Foundation

extension AppModel {
    /// Done tasks go to the done folder; the tasks that waited for them lose those met links first. Runs after every
    /// write that marks a task done and at every sync (a task done in Obsidian).
    func fileAwayDoneTasks() async {
        guard config.flags.fileDoneTasks else { return }
        for task in DoneFiling.due(tasks) { await fileAway(task) }
    }

    private func fileAway(_ task: TaskNote) async {
        for dependent in DoneFiling.unlinking(task.name, from: tasks) {
            await edit(dependent.name) { _ in [.removePreviousTask(task.name)] }
        }
        do {
            if config.flags.backups { try await services.tasks.backup([task], reason: "done") }
            try await services.tasks.fileAway(task)
            remove(task)
            await publishDerivedState()
        } catch {
            SyncLog.logger.error("filing \(task.name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The done folder's tasks, read-only, for the Done list.
    func loadFiledTasks() async {
        filedTasks = (try? await services.tasks.filedTasks()) ?? []
    }
}
