import Foundation

/// Moving notes between the vault's folders: the trash and the done folder.
extension TaskNotesStore {
    /// Into the vault's trash folder (Obsidian's `.trash`).
    func delete(_ task: TaskItem) async throws -> TrashedNote? {
        let settings = vaultSettings()
        return try await location.withRoot { root in
            let target = try folders.move(try existingURL(of: task, root: root), into: folders.trash(settings, root: root),
                                          firstNumber: 1, confirming: task.name)
            return TrashedNote(id: VaultPaths.relative(target.url, to: root), name: target.name,
                               trashedAt: fileSystem.modificationDate(of: target.url))
        }
    }

    /// Into the done folder beside the tasks folder, which Obsidian and TaskNotes do not index.
    func fileAway(_ task: TaskItem) async throws -> TaskItem {
        let settings = vaultSettings()
        return try await location.withRoot { root in
            let target = try folders.move(try existingURL(of: task, root: root), into: try folders.done(doneFolder, settings, root: root),
                                          confirming: task.name)
            return moved(task, to: target, root: root)
        }
    }

    /// Back into the tasks folder (under a free name), then reopened there: status `this_week`, no `completed_date`.
    func unfile(_ task: TaskItem) async throws -> TaskItem {
        let settings = vaultSettings()
        let back = try await location.withRoot { root in
            let target = try folders.move(try existingURL(of: task, root: root), into: folders.tasks(settings, root: root),
                                          confirming: task.name)
            return moved(task, to: target, root: root)
        }
        return try await apply([.reopen], to: back).task
    }

    /// The task at the place a move put its note.
    private func moved(_ task: TaskItem, to target: (name: String, url: URL), root: URL) -> TaskItem {
        var moved = task
        moved.name = target.name
        moved.id = TaskID(relativePath: VaultPaths.relative(target.url, to: root))
        return moved
    }

    func filedTasks() async throws -> [TaskItem] {
        let settings = vaultSettings()
        let scanner = scanner(settings)
        return try await location.withRoot { root in
            let folder = try folders.done(doneFolder, settings, root: root)
            guard fileSystem.fileExists(folder) else { return [] }
            return await scanner.scan(root: root, tasksFolder: VaultPaths.relative(folder, to: root)).result.tasks
        }
    }
}
