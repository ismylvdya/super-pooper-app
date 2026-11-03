import Foundation

/// The app's shared settings (day boundary, timeline, routines, pool order …) in the chosen folder:
/// `super-pooper-app-settings.json`, so every device reads the same ones. Not to be confused with a habit's own settings
/// (`HabitFile`).
struct VaultSettingsFile: SettingsNoteRepository {
    let location: VaultLocating
    let fileSystem: NoteFileSystem
    let fileName: String

    func read() async -> Data? {
        let file: Data?? = try? await location.withRoot { root in
            let url = root.appendingPathComponent(fileName)
            guard fileSystem.fileExists(url) else { return nil }
            return try fileSystem.read(url).text.data(using: .utf8)
        }
        return file.flatMap { $0 }
    }

    /// Pretty-printed with sorted keys, so the file reads well and changes little between writes.
    func write(_ json: Data) async throws {
        let object = try JSONSerialization.jsonObject(with: json)
        let pretty = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        let text = String(decoding: pretty, as: UTF8.self) + "\n"
        try await location.withRoot { root in try fileSystem.write(text, to: root.appendingPathComponent(fileName)) }
    }
}
