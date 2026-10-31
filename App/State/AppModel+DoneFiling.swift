import Foundation

extension AppModel {
    /// Done tasks are filed away by the store; the tasks that waited for them lose those met links first. Runs after every
    /// write that marks a task done and at every sync (a task done in Obsidian).
    func fileAwayDoneTasks() async {
        guard config.flags.fileDoneTasks else { return }
        for task in DoneFiling.due(tasks) { await fileAway(task) }
    }

    private func fileAway(_ task: TaskItem) async {
        for dependent in DoneFiling.unlinking(task.name, from: tasks) {
            await edit(dependent.name) { _ in [.removePreviousTask(task.name)] }
        }
        do {
            try await backup([task], reason: "done")
            try await services.tasks.fileAway(task)
            remove(task)
            // The Done list and its count see it before the folder is read again.
            filedTasks.append(task)
            await publishDerivedState()
        } catch {
            SyncLog.logger.error("filing \(task.name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The filed tasks, read-only, for the Done list and its count on the Lists tab.
    func loadFiledTasks() async {
        filedTasks = (try? await services.tasks.filedTasks()) ?? []
    }

    /// What a list of the Lists tab holds now, the filed tasks included.
    func listContents(_ filter: TaskListFilter, query: String) -> TaskListContents {
        filter.contents(of: tasks, filed: filedTasks, query: query, rules: config.rules.day)
    }
}
