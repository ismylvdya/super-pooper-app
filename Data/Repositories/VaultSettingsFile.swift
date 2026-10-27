import Foundation

/// The app's shared settings (day boundary, timeline, routines, pool order …) in the vault:
/// `super-pooper-app-settings.json` next to the tasks folder, so every device reads the same ones. Not to be confused
/// with an item's own settings, which live in its note (`ItemSettingsProperty`). Until the file exists, the older
/// settings note is read and its settings are written into a new file right away; the note stays as it was.
struct VaultSettingsFile: SettingsNoteRepository {
    let location: VaultLocating
    let fileSystem: NoteFileSystem
    let fileName: String
    let vaultSettings: @Sendable () -> AppSettings.Vault
    /// The older settings note, read while there is no file.
    let legacy: SettingsNoteRepository?

    func read() async -> Data? {
        let file: Data?? = try? await location.withRoot { root in
            let url = try url(root: root)
            guard fileSystem.fileExists(url) else { return nil }
            return try fileSystem.read(url).text.data(using: .utf8)
        }
        if let file = file.flatMap({ $0 }) { return file }
        guard let old = await legacy?.read() else { return nil }
        try? await write(old)
        return old
    }

    /// Pretty-printed with sorted keys, so the file reads well and changes little between writes.
    func write(_ json: Data) async throws {
        let object = try JSONSerialization.jsonObject(with: json)
        let pretty = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        let text = String(decoding: pretty, as: UTF8.self) + "\n"
        try await location.withRoot { root in try fileSystem.write(text, to: try url(root: root)) }
    }

    private func url(root: URL) throws -> URL {
        try VaultPaths.besideTasks(fileName, root: root, tasksFolder: vaultSettings().tasksFolder, fileSystem: fileSystem)
    }
}
