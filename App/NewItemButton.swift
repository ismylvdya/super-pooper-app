import SwiftUI

/// The "+" beside the tab bar, which opens the new-item page on the open tab (a habit in Habits). Upright the bubble and
/// its symbol are the system tab bar's own, of its search-role tab, with the same glass as the bar; this only takes the
/// touches over it (`NewItemSlot`). Lying sideways it is a bubble of its own at the end of the app's own tab bar. On Tasks a swipe starting on it takes the bubble itself along at once,
/// with no hold, leaving nothing in its place; let go on the timeline or in today's pool it opens the new task's page for
/// that spot, and the bubble is back (`TaskDragState.moveNewItem`, `NewItemDragOverlay`).
struct NewItemButton: View {
    @Environment(Router.self) private var router
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    /// False over the system's own bubble.
    var drawsBubble = true

    var body: some View {
        let target = router.tab == .today ? drag : nil
        let isLifted = target?.newItemPoint != nil
        Group {
            if drawsBubble {
                NewItemBubble().opacity(isLifted ? 0 : 1)
            } else {
                Color.clear.background { SearchTabBubbleVisibility(isVisible: !isLifted) }
            }
        }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { drag?.newItemSize = $0 }
            // The system tab bar under the "+" takes the touches SwiftUI's gestures would wait for: a view of UIKit's own
            // stands over it.
            .overlay {
                NewItemTouchArea(canDrag: target != nil) {
                    TabBarItem.selection(.newItem, router: router)
                } onMove: { target?.moveNewItem(to: $0) } onEnd: { target?.releaseNewItem() } onCancel: { target?.cancelNewItem() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { TabBarItem.selection(.newItem, router: router) }
            .accessibilityLabel(Text("newItem.title"))
            .accessibilityIdentifier("tabBar.newItem")
    }
}

/// The "+" in its round glass.
private struct NewItemBubble: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        Image(systemName: icons[.newItem])
            .font(tokens.font(.tabIcon))
            .foregroundStyle(tokens.color(.primaryText))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .systemLook(.newItemBubble)
            // Outside the glass: what the glass draws takes no touches by itself.
            .contentShape(Circle())
    }
}

/// The "+" under the finger, over everything on the screen, while it is dragged.
struct NewItemDragOverlay: View {
    @Environment(TaskDragState.self) private var drag

    var body: some View {
        if let point = drag.newItemPoint {
            GeometryReader { geometry in
                let origin = geometry.frame(in: .global).origin
                NewItemBubble()
                    .frame(width: drag.newItemSize.width, height: drag.newItemSize.height)
                    .position(x: point.x - origin.x, y: point.y - origin.y)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
