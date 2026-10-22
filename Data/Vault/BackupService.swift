import Foundation

/// Copies notes into the App Group before risky operations (rename, delete, mass status changes)
/// and keeps only the newest `keepCount` backups.
struct BackupService: Sendable {
    let directory: URL
    let keepCount: Int
    let fileSystem: NoteFileSystem
    let clock: @Sendable () -> Date

    @discardableResult
    func backup(_ files: [URL], reason: String) throws -> URL? {
        guard !files.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let folder = directory.appendingPathComponent("\(formatter.string(from: clock()))-\(reason)", isDirectory: true)
        for file in files where fileSystem.fileExists(file) {
            try fileSystem.copy(file, to: folder.appendingPathComponent(file.lastPathComponent))
        }
        rotate()
        return folder
    }

    private func rotate() {
        let manager = FileManager.default
        guard let folders = try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        let sorted = folders.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for folder in sorted.dropFirst(max(keepCount, 1)) {
            try? manager.removeItem(at: folder)
        }
    }
}
