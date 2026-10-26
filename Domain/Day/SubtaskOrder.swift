import Foundation

/// The order of a task's subtasks, set by dragging them on its page: the ones with a place first, by it, the rest
/// after them by name. The place is kept in each subtask (`subtask_order`), so renames do not lose it.
enum SubtaskOrder {
    static func sorted(_ subtasks: [TaskNote]) -> [TaskNote] {
        stable(NameOrder.sorted(subtasks))
    }

    /// Siblings by their places; those without one keep their order after them (in the pool: the pool's).
    static func stable<Item>(_ items: [Item], order: (Item) -> Int?) -> [Item] {
        items.enumerated()
            .sorted { (order($0.element) ?? .max, $0.offset) < (order($1.element) ?? .max, $1.offset) }
            .map(\.element)
    }

    static func stable(_ subtasks: [TaskNote]) -> [TaskNote] {
        stable(subtasks, order: \.subtaskOrder)
    }

    /// `name` dropped on `target`: it takes the target's place, the ones between shift by one. Every subtask gets
    /// its place in the new order; the result holds only the places that changed.
    static func moving(_ name: String, onto target: String, in subtasks: [TaskNote]) -> [String: Int] {
        var names = sorted(subtasks).map(\.name)
        guard name != target, let from = names.firstIndex(of: name), let to = names.firstIndex(of: target) else { return [:] }
        names.remove(at: from)
        names.insert(name, at: to)
        let current = Dictionary(subtasks.map { ($0.name, $0.subtaskOrder) }, uniquingKeysWith: { first, _ in first })
        var changed: [String: Int] = [:]
        for (place, name) in names.enumerated() where current[name] != place { changed[name] = place }
        return changed
    }
}
