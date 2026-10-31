import Foundation

/// Copies notes into the App Group before risky operations (rename, delete, mass status changes)
/// and keeps only the newest `keepCount` backups, newest by the moment in the folder name (`BackupFolderName`).
struct BackupService: Sendable {
    let directory: URL
    let keepCount: Int
    let fileSystem: NoteFileSystem
    let clock: @Sendable () -> Date
    /// The phone's calendar: folders of older versions are named by its clock.
    let calendar: CalendarSource

    @discardableResult
    func backup(_ files: [URL], reason: String) throws -> URL? {
        guard !files.isEmpty else { return nil }
        let folder = directory.appendingPathComponent(BackupFolderName.make(at: clock(), reason: reason), isDirectory: true)
        for file in files where fileSystem.fileExists(file) {
            try fileSystem.copy(file, to: folder.appendingPathComponent(file.lastPathComponent))
        }
        rotate()
        return folder
    }

    private func rotate() {
        let manager = FileManager.default
        guard let folders = try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        let zone = calendar.current.timeZone
        let newestFirst = folders
            .map { (folder: $0, moment: BackupFolderName.moment(of: $0.lastPathComponent, legacyZone: zone) ?? .distantPast) }
            .sorted { $0.moment > $1.moment }
        for old in newestFirst.dropFirst(max(keepCount, 1)) {
            try? manager.removeItem(at: old.folder)
        }
    }
}
