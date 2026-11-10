import Foundation

/// What a "+" opens: the new-item page set to a task or a habit, and where a dragged "+" landed.
struct NewItemSeed: Hashable, Sendable {
    enum Kind: Hashable, Sendable { case task, habit }

    var kind: Kind
    var placement: NewItemPlacement?
    /// The estimate picked with a second finger while the "+" was dragged.
    var estimate: Int?
}
