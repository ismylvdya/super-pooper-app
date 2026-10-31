import Foundation

/// An action a menu shows, as `actions.json` describes it, and whether it is the mark the item already has (shown, but
/// not selectable).
struct MenuEntry: Equatable {
    let action: ActionDefinition
    let isCurrent: Bool
}

extension AppModel {
    /// The actions a menu offers for `item` now, in the menu's order (`ActionAvailability`): by the item's state, the day
    /// (Skip today and Not today only on today's page) and what the task store can do.
    func menuEntries(_ menu: ActionMenu, for item: DayItem?, isToday: Bool = true) -> [MenuEntry] {
        let ids = config.actions.actions(in: menu).map(\.id)
        return ActionAvailability(capabilities: parts.capabilities, isToday: isToday).entries(ids, for: item).map {
            MenuEntry(action: config.actions.definition($0.action), isCurrent: $0.isCurrent)
        }
    }

    /// Whether the item offers the action now (a swipe that stands for a menu entry).
    func offers(_ action: ActionID, for item: DayItem, isToday: Bool = true) -> Bool {
        ActionAvailability(capabilities: parts.capabilities, isToday: isToday).isAvailable(action, for: item)
    }
}
