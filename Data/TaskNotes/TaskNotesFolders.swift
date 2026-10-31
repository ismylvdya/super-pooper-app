import Foundation

/// The folders of a TaskNotes vault — the tasks, the done folder beside them, the trash — and putting a note into one
/// under a name that is free there (`Name`, `Name 2`, …), confirmed by looking.
struct TaskNotesFolders: Sendable {
    let fileSystem: NoteFileSystem
    let noteExtension: String

    func tasks(_ settings: AppSettings.Vault, root: URL) -> URL {
        root.appendingPathComponent(VaultPaths.tasksFolder(settings.tasksFolder, in: root, exists: fileSystem.fileExists),
                                    isDirectory: true)
    }

    /// `name` (`rules.json` → `vault.doneFolder`) beside the tasks folder.
    func done(_ name: String, _ settings: AppSettings.Vault, root: URL) throws -> URL {
        try VaultPaths.besideTasks(name, root: root, tasksFolder: settings.tasksFolder, fileSystem: fileSystem)
    }

    func trash(_ settings: AppSettings.Vault, root: URL) -> URL {
        root.appendingPathComponent(settings.trashFolder, isDirectory: true)
    }

    /// The file a note named `name` gets in `folder`: the name, or the first free numbered one.
    func freeFile(for name: String, in folder: URL, firstNumber: Int = 2) -> (name: String, url: URL) {
        let names = NoteFolder(folder, fileSystem: fileSystem)
        let free = UniqueName.free(name, firstNumber: firstNumber) { names.isTaken($0) }
        return (free, folder.appendingPathComponent("\(free).\(noteExtension)"))
    }

    /// Moves the note at `source` into `folder` under a free name. A move that did not land is an error naming `name`
    /// (the note's new name when there is none).
    @discardableResult
    func move(_ source: URL, into folder: URL, firstNumber: Int = 2, confirming name: String? = nil) throws -> (name: String, url: URL) {
        try fileSystem.createFolder(folder)
        let target = freeFile(for: source.deletingPathExtension().lastPathComponent, in: folder, firstNumber: firstNumber)
        try fileSystem.move(source, to: target.url)
        guard fileSystem.isMoved(source, to: target.url) else { throw TaskStoreError.notConfirmed(name ?? target.name) }
        return target
    }
}
