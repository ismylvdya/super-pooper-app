import Foundation

/// Notes with conflicting versions (iCloud), where the store keeps them: every version, and keeping the one the user
/// picked.
@MainActor
final class ConflictResolver {
    private let versions: VersionConflictResolving?
    private let tasks: TaskState
    private let store: TaskStore
    private let backups: BackupPolicy
    private let derived: DerivedStatePublisher
    private let appEvents: AppEventSink

    init(versions: VersionConflictResolving?, tasks: TaskState, store: TaskStore, backups: BackupPolicy,
         derived: DerivedStatePublisher, appEvents: AppEventSink) {
        self.versions = versions
        self.tasks = tasks
        self.store = store
        self.backups = backups
        self.derived = derived
        self.appEvents = appEvents
    }

    /// Every version of a note in conflict, the current file first.
    func versions(of name: String) async -> [NoteVersion] {
        guard let note = tasks.task(named: name), let versions else { return [] }
        return (try? await versions.versions(of: note)) ?? []
    }

    /// Keeps the version the user picked and re-reads the tasks.
    func keep(_ version: NoteVersion, of name: String) async {
        guard let note = tasks.task(named: name), let versions else { return }
        do {
            try await backups.backup([note], reason: "conflict")
            try await versions.keep(version.id, of: note)
            appEvents.send(.conflictResolved(name))
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        await tasks.reload(from: store)
        await derived.publish()
    }
}
