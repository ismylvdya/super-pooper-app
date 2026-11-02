import Foundation

/// Overlapping blocks as Calendar lays them out: a block that starts far enough below an earlier one it overlaps (past
/// the room the earlier one's title needs) lies over it, indented one step more than the blocks it covers, so every
/// title stays readable; blocks that start too close to share it this way stand side by side in columns, together
/// indented as the first of them.
enum CascadeAssigner {
    struct Block: Sendable {
        let top: Double
        let bottom: Double
        /// How far below its top a block's title reaches: a later block starting within it would cover the title.
        let titleRoom: Double
    }

    struct Placement: Hashable, Sendable {
        /// Indent steps from the left edge.
        let indent: Int
        let column: Int
        let columnCount: Int
    }

    /// `blocks` in drawing order, earliest first (a later block is drawn over an earlier one); the result keeps it.
    static func assign(_ blocks: [Block]) -> [Placement] {
        var groups: [(indent: Int, members: [Int])] = []
        var groupOf: [Int] = []
        for (index, block) in blocks.enumerated() {
            let covered = blocks.indices.prefix(index).filter { blocks[$0].bottom > block.top && blocks[$0].top < block.bottom }
            if let near = covered.first(where: { block.top - blocks[$0].top < blocks[$0].titleRoom }) {
                groups[groupOf[near]].members.append(index)
                groupOf.append(groupOf[near])
            } else {
                groups.append((covered.map { groups[groupOf[$0]].indent + 1 }.max() ?? 0, [index]))
                groupOf.append(groups.count - 1)
            }
        }
        return blocks.indices.map { index in
            let group = groups[groupOf[index]]
            return Placement(indent: group.indent, column: group.members.firstIndex(of: index) ?? 0, columnCount: group.members.count)
        }
    }
}
