import Foundation

/// An item's identity in its store, opaque to everything but the store that made it. It changes when the store moves
/// the item (a rename). References between items go by name (`NoteName`), not by this.
struct TaskID: Hashable, Codable, Sendable {
    /// What the store keeps; only the store reads it.
    let value: String

    init(_ value: String) {
        self.value = value
    }

    /// The identity of a draft, not stored yet.
    static let unsaved = TaskID("")
}
