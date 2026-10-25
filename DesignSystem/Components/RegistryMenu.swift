import SwiftUI

/// The buttons of a menu from the action registry (`actions.json`): titles, icons, order and the destructive
/// role come from there. For menus whose items do not depend on an item's state (events, reminders).
struct RegistryMenu: View {
    @Environment(\.actions) private var actions
    let menu: ActionMenu
    let perform: (ActionDefinition) -> Void

    var body: some View {
        ForEach(actions.actions(in: menu), id: \.id) { action in
            Button(role: action.destructive ? .destructive : nil) { perform(action) } label: {
                Label(LocalizedStringKey(action.title), systemImage: action.icon)
            }
        }
    }
}
