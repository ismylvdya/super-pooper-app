import Foundation

/// The thin lines from a parent to its subtasks in the pool, as each row draws its part of them in the room its indent
/// leaves: at its own level a line comes down from the row above and turns right into its plate, and goes on down when
/// a later sibling follows; at a higher level a line passes by when an ancestor's later sibling is still to come.
struct SubtaskGuide: Equatable, Sendable {
    /// The row's level: 1 for a subtask, 2 for a subtask of a subtask.
    let depth: Int
    /// No later sibling under the same parent: the line ends at this row.
    let isLast: Bool
    /// For the levels above (1 up to `depth - 1`): a line passes this row there.
    let passes: [Bool]
}

enum SubtaskGuides {
    /// The guides of the subtasks among `items`, in the pool's order (a subtask right under its parent and siblings).
    static func guides(of items: [DayItem]) -> [String: SubtaskGuide] {
        var guides: [String: SubtaskGuide] = [:]
        for (index, item) in items.enumerated() where item.depth > 0 {
            let later = items[(index + 1)...]
            let passes = (1..<item.depth).map { hasSibling(at: $0, in: later) }
            guides[item.id] = SubtaskGuide(depth: item.depth, isLast: !hasSibling(at: item.depth, in: later), passes: passes)
        }
        return guides
    }

    /// A later row stands at `level` before any row above that level ends the family.
    private static func hasSibling(at level: Int, in later: ArraySlice<DayItem>) -> Bool {
        for item in later {
            if item.depth < level { return false }
            if item.depth == level { return true }
        }
        return false
    }
}
