import Foundation

/// The settings note in the vault: `SuperPooper Settings.md` next to the tasks folder (inside the
/// TaskNotes folder), with the settings as JSON in a ```SuperPooperApp block.
protocol SettingsNoteRepository: Sendable {
    func read() async -> Data?
    func write(_ json: Data) async throws
}

struct VaultSettingsNote: SettingsNoteRepository {
    let location: VaultLocating
    let fileSystem: NoteFileSystem
    let fileName: String
    let vaultSettings: @Sendable () -> AppSettings.Vault

    func read() async -> Data? {
        try? await location.withRoot { root in
            let url = try noteURL(root: root)
            guard fileSystem.fileExists(url) else { return nil }
            return AppBlock.json(in: try fileSystem.read(url).text)
        }
    }

    /// Replaces only the block; text written around it in Obsidian stays.
    func write(_ json: Data) async throws {
        try await location.withRoot { root in
            let url = try noteURL(root: root)
            let current = fileSystem.fileExists(url) ? try fileSystem.read(url).text : L10n.string("settingsNote.intro")
            let split = AppBlock.split(current)
            let visible = split.block.isEmpty ? current : split.visible
            try fileSystem.write(AppBlock.join(block: AppBlock.make(json: json), visible: visible), to: url)
        }
    }

    /// Next to the tasks folder: `TaskNotes/` when the vault is chosen, the chosen folder itself otherwise.
    private func noteURL(root: URL) throws -> URL {
        let tasks = VaultPaths.tasksFolder(vaultSettings().tasksFolder, in: root, exists: fileSystem.fileExists)
        let parent = (tasks as NSString).deletingLastPathComponent
        return root.appendingPathComponent(parent, isDirectory: true).appendingPathComponent(fileName)
    }
}
