import Foundation

extension AppModel {
    /// Re-reads the trash folder (the trash screen and the Settings counter).
    func refreshTrash() async {
        setTrash((try? await services.trash?.notes()) ?? [])
    }

    func trashedText(_ note: TrashedNote) async -> String {
        (try? await services.trash?.text(of: note)) ?? ""
    }

    func restore(_ note: TrashedNote) async {
        do {
            guard let trash = services.trash else { return }
            let name = try await trash.restore(note)
            appEvents.send(.restored(name))
            if let result = try? await services.tasks.load() { setScanResult(result) }
            await publishDerivedState()
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        await refreshTrash()
    }

    func deletePermanently(_ note: TrashedNote) async {
        do {
            try await services.trash?.deletePermanently(note)
            appEvents.send(.deletedForever(note.name))
        } catch {
            appEvents.send(.failure(AppFailure(error)))
        }
        await refreshTrash()
    }

    var trashCount: Int? { trashedNotes.isEmpty ? nil : trashedNotes.count }
}
