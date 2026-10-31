import Foundation

/// What the TaskNotes store offers beyond the basics: iCloud conflict versions, links into Obsidian, backups and what
/// the chosen folder is.
extension TaskNotesStore: VersionConflictResolving, ExternalLinking, TaskBackups, FolderInspecting {
    func backup(_ tasks: [TaskItem], reason: String) async throws {
        try await location.withRoot { root in
            _ = try backups.backup(tasks.map { root.appendingPathComponent($0.id.relativePath) }, reason: reason)
        }
    }

    /// `obsidian://open?vault=…&file=…`.
    func externalURL(for task: TaskItem) async -> URL? {
        let settings = vaultSettings()
        return try? await location.withRoot { root in
            ObsidianLink.url(relativePath: task.id.relativePath, root: root, folder: chosenFolder(root: root),
                             vaultName: settings.obsidianVault, pathPrefix: settings.obsidianPathPrefix, obsidian: obsidian)
        }
    }

    func versions(of task: TaskItem) async throws -> [NoteVersion] {
        try await location.withRoot { root in try ubiquity.versions(of: try existingURL(of: task, root: root)) }
    }

    func keep(_ versionID: String, of task: TaskItem) async throws {
        try await location.withRoot { root in
            let url = try existingURL(of: task, root: root)
            try ubiquity.keep(versionID, of: url)
            seenModification[task.id.relativePath] = fileSystem.modificationDate(of: url)
        }
    }

    func chosenFolder() async -> ChosenFolder {
        (try? await location.withRoot { root in chosenFolder(root: root) }) ?? ChosenFolder()
    }

    private func chosenFolder(root: URL) -> ChosenFolder {
        ChosenFolder(isWholeVault: VaultPaths.isWholeVault(root, configFolder: obsidian.configFolder, exists: fileSystem.fileExists),
                     obsidianPlace: VaultPaths.obsidianPlace(of: root, vaultsFolder: obsidian.vaultsFolder))
    }
}
