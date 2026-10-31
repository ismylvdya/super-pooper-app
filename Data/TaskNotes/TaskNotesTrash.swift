import Foundation

/// The vault's trash folder (Obsidian's `.trash`): deleted notes are moved there and back.
struct TaskNotesTrash: TaskTrash {
    let location: VaultLocating
    let fileSystem: NoteFileSystem
    let noteExtension: String
    let vaultSettings: @Sendable () -> AppSettings.Vault

    func notes() async throws -> [TrashedNote] {
        let settings = vaultSettings()
        return try await location.withRoot { root in
            let folder = root.appendingPathComponent(settings.trashFolder, isDirectory: true)
            guard fileSystem.fileExists(folder) else { return [] }
            return try fileSystem.listFiles(in: folder)
                .filter { $0.pathExtension == noteExtension && !$0.lastPathComponent.hasPrefix(".") }
                .map { url in
                    TrashedNote(id: VaultPaths.relative(url, to: root), name: url.deletingPathExtension().lastPathComponent,
                                trashedAt: fileSystem.modificationDate(of: url))
                }
                .sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) }
        }
    }

    func text(of note: TrashedNote) async throws -> String {
        try await location.withRoot { root in try fileSystem.read(root.appendingPathComponent(note.id)).text }
    }

    func restore(_ note: TrashedNote) async throws -> String {
        let settings = vaultSettings()
        return try await location.withRoot { root in
            let source = root.appendingPathComponent(note.id)
            let folder = root.appendingPathComponent(VaultPaths.tasksFolder(settings.tasksFolder, in: root, exists: fileSystem.fileExists),
                                                     isDirectory: true)
            let names = NoteFolder(folder, fileSystem: fileSystem)
            let name = UniqueName.free(note.name) { names.isTaken($0) }
            let target = folder.appendingPathComponent("\(name).\(noteExtension)")
            try fileSystem.move(source, to: target)
            guard fileSystem.isMoved(source, to: target) else { throw TaskStoreError.notConfirmed(name) }
            return name
        }
    }

    func deletePermanently(_ note: TrashedNote) async throws {
        try await location.withRoot { root in
            let url = root.appendingPathComponent(note.id)
            try fileSystem.remove(url)
            guard !fileSystem.fileExists(url) else { throw TaskStoreError.notConfirmed(note.name) }
        }
    }
}
