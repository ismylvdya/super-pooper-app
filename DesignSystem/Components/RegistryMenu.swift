import SwiftUI

/// The buttons of a menu from the action registry (`actions.json`): titles, icons, order and the destructive
/// role come from there, the rarer ones under a divider. For menus whose items do not depend on an item's state (events,
/// reminders).
struct RegistryMenu: View {
    @Environment(\.actions) private var actions
    let menu: ActionMenu
    let perform: (ActionDefinition) -> Void

    var body: some View {
        let definition = actions.menus[menu]
        MenuSections(frequent: definition.frequent.map(actions.definition), more: definition.more.map(actions.definition)) { action in
            Button(role: action.destructive ? .destructive : nil) { perform(action) } label: { ActionLabel(action: action) }
        }
    }
}
