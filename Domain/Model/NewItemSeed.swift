import Foundation

/// What a "+" opens: the new-item page set to a task or a habit.
struct NewItemSeed: Hashable, Sendable {
    enum Kind: Hashable, Sendable { case task, habit }

    var kind: Kind
}
