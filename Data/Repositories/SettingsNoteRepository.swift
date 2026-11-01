import Foundation

/// Where the app's shared settings live in the vault (see `VaultSettingsFile`).
protocol SettingsNoteRepository: Sendable {
    func read() async -> Data?
    func write(_ json: Data) async throws
}

/// Settings kept where an older version kept them, only read.
protocol LegacySettingsReading: Sendable {
    func read() async -> Data?
}

/// The older settings note: `SuperPooper Settings.md` next to the tasks folder, with every setting as a property of
/// its own (see `SettingsProperties`); older still, the JSON in a ```SuperPooperApp block. Read by
/// `VaultSettingsFile` until its JSON file exists; never written.
struct VaultSettingsNote: LegacySettingsReading {
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
}
