import Foundation

/// A note in the vault's trash folder (`.trash`), where the app moves deleted notes.
struct TrashedNote: Identifiable, Hashable, Sendable {
    let name: String
    /// Path relative to the vault root, e.g. `.trash/Name.md`.
    let relativePath: String
    /// When it was moved there (the file's modification date).
    let trashedAt: Date?
    var id: String { relativePath }
}

/// The trash screen's data: list, read, restore into the tasks folder, delete for good.
protocol TrashRepository: Sendable {
    func notes() async throws -> [TrashedNote]
    func text(of note: TrashedNote) async throws -> String
    /// Moves the note back into the tasks folder (the name is made unique) and returns its new name.
    func restore(_ note: TrashedNote) async throws -> String
    func deletePermanently(_ note: TrashedNote) async throws
}

struct VaultTrashRepository: TrashRepository {
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
                    TrashedNote(name: url.deletingPathExtension().lastPathComponent,
                                relativePath: VaultPaths.relative(url, to: root),
                                trashedAt: fileSystem.modificationDate(of: url))
                }
                .sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) }
        }
    }

    func text(of note: TrashedNote) async throws -> String {
        try await location.withRoot { root in try fileSystem.read(root.appendingPathComponent(note.relativePath)).text }
    }

    func restore(_ note: TrashedNote) async throws -> String {
        let settings = vaultSettings()
        return try await location.withRoot { root in
            let source = root.appendingPathComponent(note.relativePath)
            let folder = root.appendingPathComponent(VaultPaths.tasksFolder(settings.tasksFolder, in: root, exists: fileSystem.fileExists),
                                                     isDirectory: true)
            let names = NoteFolder(folder, fileSystem: fileSystem)
            let name = UniqueName.free(note.name) { names.isTaken($0) }
            let target = folder.appendingPathComponent("\(name).\(noteExtension)")
            try fileSystem.move(source, to: target)
            guard fileSystem.isMoved(source, to: target) else { throw TaskRepositoryError.notConfirmed(name) }
            return name
        }
    }

    func deletePermanently(_ note: TrashedNote) async throws {
        try await location.withRoot { root in
            let url = root.appendingPathComponent(note.relativePath)
            try fileSystem.remove(url)
            guard !fileSystem.fileExists(url) else { throw TaskRepositoryError.notConfirmed(note.name) }
        }
    }
}
