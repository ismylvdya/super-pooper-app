import Foundation

/// Where a "+" held over the pool puts the new task, by the row just above its gap: over the left part of the pool it
/// stands beside that row, at its level (under the same parent); over the right part (`rules.json` →
/// `gestures.subtaskShare` of the width) it is that row's first subtask. A habit takes no subtasks here.
enum NewItemNesting {
    struct Spot: Equatable, Sendable {
        /// The task it goes under; nil: a task of the pool's top level.
        var parent: String?
        var depth = 0
        /// Its place among the parent's subtasks.
        var index: Int?

        static let top = Spot()
    }

    /// `order`: the pool's ids with the gap among them; `pool`: the rows as the day shows them (depths and all).
    static func spot(order: [String], gap: String, pool: [DayItem], asSubtask: Bool) -> Spot {
        let byID = Dictionary(pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard let at = order.firstIndex(of: gap), at > 0, let above = byID[order[at - 1]], !above.isHabit else { return .top }
        if asSubtask { return Spot(parent: above.id, depth: above.depth + 1, index: 0) }
        guard above.depth > 0 else { return .top }
        let before = order[..<at].compactMap { byID[$0] }
        guard let parentAt = before.lastIndex(where: { $0.depth == above.depth - 1 }) else { return .top }
        let siblings = before[(parentAt + 1)...].filter { $0.depth == above.depth }.count
        return Spot(parent: before[parentAt].id, depth: above.depth, index: siblings)
    }

    /// The finger is over the part of the pool that makes a subtask.
    static func isSubtaskSide(x: Double, poolMinX: Double, poolWidth: Double, share: Double) -> Bool {
        x > poolMinX + poolWidth * (1 - share)
    }
}
