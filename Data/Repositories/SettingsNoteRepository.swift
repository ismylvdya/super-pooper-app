import Foundation

/// Where the app's shared settings live in the vault (see `VaultSettingsFile`).
protocol SettingsNoteRepository: Sendable {
    func read() async -> Data?
    func write(_ json: Data) async throws
}

/// The older settings note: `SuperPooper Settings.md` next to the tasks folder, with every setting as a property of
/// its own (see `SettingsProperties`); older still, the JSON in a ```SuperPooperApp block. Read by
/// `VaultSettingsFile` until its JSON file exists.
struct VaultSettingsNote: SettingsNoteRepository {
    let location: VaultLocating
    let fileSystem: NoteFileSystem
    let fileName: String
    let vaultSettings: @Sendable () -> AppSettings.Vault

    /// The properties over the old block (if any); nil when the note has neither.
    func read() async -> Data? {
        try? await location.withRoot { root in
            let url = try VaultPaths.besideTasks(fileName, root: root, tasksFolder: vaultSettings().tasksFolder, fileSystem: fileSystem)
            guard fileSystem.fileExists(url) else { return nil }
            let text = try fileSystem.read(url).text
            guard let document = try? FrontmatterDocument(text: text) else { return AppBlock.json(in: text) }
            let legacy = AppBlock.json(in: document.body)
            let properties = document.keys.compactMap { key in
                (try? document.value(for: key)).map { SettingsProperties.Property(key: key, value: $0) }
            }
            guard !properties.isEmpty else { return legacy }
            let json = try SettingsProperties.json(from: properties)
            return try legacy.map { try JSONMerge.merge(base: $0, overlay: json) } ?? json
        }
    }

    /// Rewrites the settings properties; other properties and the text written in Obsidian stay. A note without
    /// frontmatter gets one; a note whose frontmatter does not parse is not touched (the error is thrown), so what
    /// the user wrote there never moves into the text.
    func write(_ json: Data) async throws {
        try await location.withRoot { root in
            let url = try VaultPaths.besideTasks(fileName, root: root, tasksFolder: vaultSettings().tasksFolder, fileSystem: fileSystem)
            let current = fileSystem.fileExists(url) ? try fileSystem.read(url).text : L10n.string("settingsNote.intro")
            var document: FrontmatterDocument
            do {
                document = try FrontmatterDocument(text: current)
            } catch FrontmatterError.noFrontmatter {
                document = try FrontmatterDocument(text: "---\n---\n" + current)
            }
            let properties = try SettingsProperties.properties(from: json)
            let roots = try SettingsProperties.roots(of: json)
            let written = Set(properties.map(\.key))
            for key in document.keys where roots.contains(SettingsProperties.root(of: key)) && !written.contains(key) {
                document.remove(key)
            }
            for property in properties { document.set(property.key, to: property.value) }
            try fileSystem.write(document.text(withBody: AppBlock.split(document.body).visible), to: url)
        }
    }
}

extension VaultPaths {
    /// A file next to the tasks folder: in `TaskNotes/` when the vault is chosen, the chosen folder itself otherwise.
    static func besideTasks(_ fileName: String, root: URL, tasksFolder: String, fileSystem: NoteFileSystem) throws -> URL {
        let tasks = VaultPaths.tasksFolder(tasksFolder, in: root, exists: fileSystem.fileExists)
        let parent = (tasks as NSString).deletingLastPathComponent
        return root.appendingPathComponent(parent, isDirectory: true).appendingPathComponent(fileName)
    }
}
