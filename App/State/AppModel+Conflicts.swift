import Foundation

extension AppModel {
    /// Every version of a note in an iCloud conflict (the current file first).
    func versions(of name: String) async -> [NoteVersion] {
        guard let note = task(named: name) else { return [] }
        return (try? await services.tasks.versions(of: note)) ?? []
    }

    /// Keeps the version the user picked and re-reads the vault.
    func keep(_ version: NoteVersion, of name: String) async {
        guard let note = task(named: name) else { return }
        do {
            if config.flags.backups { try await services.tasks.backup([note], reason: "conflict") }
            try await services.tasks.keep(version.id, of: note)
            banners.show(L10n.format("banner.conflictResolved", name), style: .success)
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
        if let result = try? await services.tasks.scan() { setScanResult(result) }
        await publishDerivedState()
    }
}
