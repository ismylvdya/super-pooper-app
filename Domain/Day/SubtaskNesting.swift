import Foundation

/// Subtasks in the pool: each right under its parent (after the parent's earlier subtasks), one level deeper,
/// whatever the sort does to the other tasks; siblings in the order set on the parent's page, the others after
/// them in pool order. A subtask whose parent is not in the list stays where it was.
enum SubtaskNesting {
    static func nested(_ items: [DayItem]) -> [DayItem] {
        let byName = Dictionary(items.map { ($0.id.lowercased(), $0.id) }, uniquingKeysWith: { first, _ in first })
        var children: [String: [DayItem]] = [:]
        var roots: [DayItem] = []
        for item in items {
            let parent = item.task.projects.lazy.compactMap { byName[$0.lowercased()] }.first { $0 != item.id }
            if let parent { children[parent, default: []].append(item) } else { roots.append(item) }
        }
        var result: [DayItem] = []
        var placed: Set<String> = []
        func place(_ item: DayItem, depth: Int) {
            guard placed.insert(item.id).inserted else { return }
            var nested = item
            nested.depth = depth
            result.append(nested)
            for child in SubtaskOrder.stable(children[item.id] ?? [], order: \.task.subtaskOrder) { place(child, depth: depth + 1) }
        }
        for root in roots { place(root, depth: 0) }
        // Subtasks of each other (a loop of parents) have no root: they keep their places at the end.
        for item in items where !placed.contains(item.id) { place(item, depth: 0) }
        return result
    }
}
