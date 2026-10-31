import Foundation

/// Moving notes between the vault's folders: the trash and the done folder.
extension TaskNotesStore {
    /// Into the vault's trash folder (Obsidian's `.trash`).
    func delete(_ task: TaskItem) async throws {
        let settings = vaultSettings()
        try await location.withRoot { root in
            try folders.move(try existingURL(of: task, root: root), into: folders.trash(settings, root: root), firstNumber: 1,
                             confirming: task.name)
        }
    }

    /// Into the done folder beside the tasks folder, which Obsidian and TaskNotes do not index.
    func fileAway(_ task: TaskItem) async throws {
        let settings = vaultSettings()
        try await location.withRoot { root in
            try folders.move(try existingURL(of: task, root: root), into: try folders.done(doneFolder, settings, root: root), confirming: task.name)
        }
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
