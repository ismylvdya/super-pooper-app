import Foundation

/// Which actions of a menu the selected items of the pool offer (Select mode): an action is offered when at least one of
/// them can take it (`ActionAvailability`). Worm needs two open tasks of the pool's top level that are not all in one
/// worm already; Unworm a selected task in a worm; New section any selected task. Delete takes tasks only: not offered
/// for habits alone. Not today is for tasks alone; with a habit among them Skip today stands in its place and sends the
/// tasks away as Not today.
struct BatchAvailability: Sendable {
    let single: ActionAvailability

    func isAvailable(_ action: ActionID, for items: [DayItem]) -> Bool {
        guard !items.isEmpty else { return false }
        switch action {
        case .worm: return canWorm(items)
        case .unworm: return items.contains { single.worm(of: $0.id) != nil }
        case .newSection: return true
        case .delete: return items.contains { !$0.isHabit }
        case .notToday: return !items.contains(where: \.isHabit) && items.contains { single.isAvailable(.notToday, for: $0) }
        case .select: return false
        default: return items.contains { single.isAvailable(action, for: $0) }
        }
    }

    /// The menu's frequent and rarer actions the selection offers, each in the menu's order.
    func entries(_ menu: MenuDefinition, for items: [DayItem]) -> (frequent: [ActionID], more: [ActionID]) {
        (menu.frequent.filter { isAvailable($0, for: items) }, menu.more.filter { isAvailable($0, for: items) })
    }

    /// Who takes the action of the selection bar: Delete leaves the habits alone; Skip today is Not today for a task.
    static func targets(of action: ActionID, in items: [DayItem]) -> [(action: ActionID, items: [DayItem])] {
        switch action {
        case .delete: return [(.delete, items.filter { !$0.isHabit })]
        case .skipToday: return [(.skipToday, items.filter(\.isHabit)), (.notToday, items.filter { !$0.isHabit })]
        default: return [(action, items)]
        }
    }

    /// The tasks a worm takes of the selection: the open ones of the pool's top level (a subtask stays with its parent).
    static func wormable(_ items: [DayItem]) -> [DayItem] {
        items.filter { $0.depth == 0 && !$0.isDone }
    }

    private func canWorm(_ items: [DayItem]) -> Bool {
        let members = Self.wormable(items)
        guard members.count > 1 else { return false }
        let worms = Set(members.map { single.worm(of: $0.id)?.id })
        return worms.count > 1 || worms.contains(nil)
    }
}
