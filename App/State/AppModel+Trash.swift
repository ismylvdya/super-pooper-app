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
            banners.show(L10n.format("banner.restored", name), style: .success)
            if let result = try? await services.tasks.load() { setScanResult(result) }
            await publishDerivedState()
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
        await refreshTrash()
    }

    func deletePermanently(_ note: TrashedNote) async {
        do {
            try await services.trash?.deletePermanently(note)
            banners.show(L10n.format("banner.deletedForever", note.name), style: .success)
        } catch {
            banners.show(Self.describe(error), style: .problem)
        }
        await refreshTrash()
    }

    var trashCount: Int? { trashedNotes.isEmpty ? nil : trashedNotes.count }
}
