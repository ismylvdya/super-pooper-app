import Foundation

/// An action a menu shows, as `actions.json` describes it, whether it is the mark the item already has (shown, but
/// not selectable), and whether it is one of the rarer ones under the divider.
struct MenuEntry: Equatable {
    let action: ActionDefinition
    let isCurrent: Bool
    var isMore = false
}

extension AppModel {
    /// The actions a menu offers for `item` now, in the menu's order (`ActionAvailability`): by the item's state, the day
    /// (Skip today and Not today only on today's page) and what the task store can do.
    func menuEntries(_ menu: ActionMenu, for item: DayItem?, isToday: Bool = true) -> [MenuEntry] {
        let definition = config.actions.menus[menu]
        return ActionAvailability(capabilities: parts.capabilities, isToday: isToday).entries(definition.actions, for: item).map {
            MenuEntry(action: config.actions.definition($0.action), isCurrent: $0.isCurrent, isMore: definition.more.contains($0.action))
        }
    }

    /// The swipe buttons a row offers now (`actions.json` → `swipes`, `ActionAvailability`): to the right, to the left.
    func swipeActions(_ swipes: ActionSwipes, for item: DayItem?, isToday: Bool = true) -> SwipeActions {
        let availability = ActionAvailability(capabilities: parts.capabilities, isToday: isToday)
        let definition = config.actions.swipes[swipes]
        let actions = { (ids: [ActionID]) in availability.swipe(ids, for: item).map(self.config.actions.definition) }
        return SwipeActions(leading: actions(definition.leading), trailing: actions(definition.trailing))
    }
}

/// The swipe buttons of a row, each side from the edge in (the first runs on a full swipe).
struct SwipeActions: Equatable {
    let leading: [ActionDefinition]
    let trailing: [ActionDefinition]
}
