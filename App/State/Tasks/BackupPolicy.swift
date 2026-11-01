import Foundation

/// A copy of the notes before a risky change (rename, delete, filing, a conflict, auto-promotion), when backups are on
/// and the store makes them.
struct BackupPolicy {
    let isOn: Bool
    let backups: TaskBackups?

    func backup(_ tasks: [TaskItem], reason: String) async throws {
        guard isOn, let backups else { return }
        try await backups.backup(tasks, reason: reason)
    }
}
