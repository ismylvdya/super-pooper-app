import SwiftUI

/// The app's own "+" beside the tab bar: a round bubble that opens the new-item page on the open tab (a habit in
/// Habits). Upright it stands over the room the system tab bar keeps for its search-role tab (`NewItemSlot`); lying
/// sideways at the end of the app's own tab bar.
struct NewItemButton: View {
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        Button { TabBarItem.selection(.newItem, router: router) } label: {
            Image(systemName: icons[.newItem])
                .font(tokens.font(.tabIcon))
                .foregroundStyle(tokens.color(.primaryText))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .systemLook(.newItemBubble)
        .accessibilityLabel(Text("newItem.title"))
        .accessibilityIdentifier("tabBar.newItem")
    }
}
