import Foundation

extension AppModel {
    /// Every version of a note in an iCloud conflict (the current file first).
    func versions(of name: String) async -> [NoteVersion] {
        guard let note = task(named: name), let versions = services.versions else { return [] }
        return (try? await versions.versions(of: note)) ?? []
    }

    /// Keeps the version the user picked and re-reads the vault.
    func keep(_ version: NoteVersion, of name: String) async {
        guard let note = task(named: name), let versions = services.versions else { return }
        do {
            try await backup([note], reason: "conflict")
            try await versions.keep(version.id, of: note)
            appEvents.send(.conflictResolved(name))
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        if let result = try? await services.tasks.load() { setScanResult(result) }
        await publishDerivedState()
    }
}
