import Foundation

/// An item in the store's trash (TaskNotes: a note in the vault's `.trash`).
struct TrashedNote: Identifiable, Hashable, Sendable {
    /// Where the trash keeps it; only the trash reads it.
    let id: String
    let name: String
    /// When it was moved there.
    let trashedAt: Date?
}

/// The store's trash, for the trash screen: list, read, restore among the tasks, delete for good. Optional: a store
/// without a trash deletes for good and the app has no trash screen.
protocol TaskTrash: Sendable {
    func notes() async throws -> [TrashedNote]
    func text(of note: TrashedNote) async throws -> String
    /// Moves the note back into the tasks folder (the name is made unique) and returns its new name.
    func restore(_ note: TrashedNote) async throws -> String
    func deletePermanently(_ note: TrashedNote) async throws
}
