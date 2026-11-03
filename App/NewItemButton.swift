import SwiftUI

/// The app's own "+" beside the tab bar: a round bubble that opens the new-item page on the open tab (a habit in
/// Habits). Upright it stands over the room the system tab bar keeps for its search-role tab (`NewItemSlot`); lying
/// sideways at the end of the app's own tab bar. On Tasks a long press lifts it, as a pool row is lifted: let go on the
/// timeline or in today's pool it opens the new task's page for that spot (`TaskDragState.beginNewItem`).
struct NewItemButton: View {
    @Environment(Router.self) private var router
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        Button { TabBarItem.selection(.newItem, router: router) } label: { symbol }
            .buttonStyle(.plain)
            .systemLook(.newItemBubble)
            .modifier(NewItemDragSource(drag: router.tab == .today ? drag : nil) { symbol.systemLook(.newItemBubble) })
            .accessibilityLabel(Text("newItem.title"))
            .accessibilityIdentifier("tabBar.newItem")
    }

    private var symbol: some View {
        Image(systemName: icons[.newItem])
            .font(tokens.font(.tabIcon))
            .foregroundStyle(tokens.color(.primaryText))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
    }
}

/// The "+" picked up: the system's lift of its round bubble, under the finger at the bubble's size.
private struct NewItemDragSource<Preview: View>: ViewModifier {
    let drag: TaskDragState?
    @ViewBuilder let preview: () -> Preview
    @State private var size: CGSize?

    func body(content: Content) -> some View {
        if let drag {
            content
                .contentShape(.dragPreview, Capsule())
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                .onDrag { drag.beginNewItem() } preview: {
                    preview()
                        .frame(width: size?.width, height: size?.height)
                        .contentShape(.dragPreview, Capsule())
                }
        } else {
            content
        }
    }
}
