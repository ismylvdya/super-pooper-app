import SwiftUI

/// The app's own "+" beside the tab bar: a round bubble that opens the new-item page on the open tab (a habit in
/// Habits). Upright it stands over the room the system tab bar keeps for its search-role tab (`NewItemSlot`); lying
/// sideways at the end of the app's own tab bar. On Tasks a swipe starting on it takes the bubble itself along at once,
/// with no hold; let go on the timeline or in today's pool it opens the new task's page for that spot, and the bubble is
/// back in its place (`TaskDragState.moveNewItem`, `NewItemDragOverlay`).
struct NewItemButton: View {
    @Environment(Router.self) private var router
    @Environment(TaskDragState.self) private var drag: TaskDragState?

    var body: some View {
        Button { TabBarItem.selection(.newItem, router: router) } label: { NewItemBubble() }
            .buttonStyle(.plain)
            .modifier(NewItemDragSource(drag: router.tab == .today ? drag : nil))
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
            .contentShape(Capsule())
            .systemLook(.newItemBubble)
    }
}

/// A swipe from the "+": it leaves its place and follows the finger in `NewItemDragOverlay`, until the finger lifts.
private struct NewItemDragSource: ViewModifier {
    @Environment(\.rules) private var rules
    let drag: TaskDragState?
    @GestureState private var isHeld = false

    func body(content: Content) -> some View {
        if let drag {
            content
                .opacity(drag.newItemPoint == nil ? 1 : 0)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { drag.newItemSize = $0 }
                .highPriorityGesture(
                    DragGesture(minimumDistance: rules.gestures.tapSlop, coordinateSpace: .global)
                        .updating($isHeld) { _, state, _ in state = true }
                        .onChanged { drag.moveNewItem(to: $0.location) }
                        .onEnded { _ in drag.releaseNewItem() }
                )
                // The system took the touch away (a call, a sheet): the "+" just goes back.
                .onChange(of: isHeld) { _, held in if !held, drag.newItemPoint != nil { drag.cancelNewItem() } }
        } else {
            content
        }
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
