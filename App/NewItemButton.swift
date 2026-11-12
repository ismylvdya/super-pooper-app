import SwiftUI

/// The "+" beside the tab bar, which opens the new-item page on the open tab (a habit in Habits). Upright the bubble and
/// its symbol are the system tab bar's own, of its search-role tab, with the same glass as the bar; this only takes the
/// touches over it (`NewItemSlot`). Lying sideways it is a bubble of its own at the end of the app's own tab bar. On Tasks a swipe starting on it takes the bubble itself along at once,
/// with no hold, leaving nothing in its place; let go on the timeline or in today's pool it opens the new task's page for
/// that spot, and the bubble is back (`TaskDragState.moveNewItem`, `NewItemDragOverlay`).
struct NewItemButton: View {
    @Environment(Router.self) private var router
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    @Environment(\.rules) private var rules
    /// False over the system's own bubble.
    var drawsBubble = true

    var body: some View {
        // Dragged only on Tasks' own page, over its pool and timeline; elsewhere (Lists, a task's page) it is tapped.
        let target = router.tab == .today && router.path.isEmpty ? drag : nil
        let isLifted = target?.newItemPoint != nil
        Group {
            if drawsBubble {
                NewItemBubble().opacity(isLifted ? 0 : 1)
            } else {
                Color.clear.background { SearchTabBubbleVisibility(isVisible: !isLifted) }
            }
        }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                drag?.newItemSize = frame.size
                drag?.newItemHome = frame
            }
            // The system tab bar under the "+" takes the touches SwiftUI's gestures would wait for: a view of UIKit's own
            // stands over it.
            .overlay {
                NewItemTouchArea(canDrag: target != nil) {
                    TabBarItem.selection(.newItem, router: router)
                } onMove: { target?.moveNewItem(to: $0) } onEnd: { target?.releaseNewItem() } onCancel: { target?.cancelNewItem() }
                onSecondFinger: { rise in pickEstimate(rise, on: target) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { TabBarItem.selection(.newItem, router: router) }
            .accessibilityLabel(Text("newItem.title"))
            .accessibilityIdentifier("tabBar.newItem")
    }

    /// A second finger down or up picks the new task's estimate (`gestures.estimateLongerDown`), a step to feel at each one;
    /// lifted, the pick stays.
    private func pickEstimate(_ rise: CGFloat?, on drag: TaskDragState?) {
        guard let drag, let rise else { return }
        let picked = NewItemEstimate.minutes(options: rules.timeEstimates.map(\.minutes), default: rules.day.defaultEstimateMinutes,
                                             rise: Double(rise), step: rules.gestures.estimateStepShare,
                                             longerDown: rules.gestures.estimateLongerDown)
        guard picked != drag.newItemEstimate else { return }
        drag.newItemEstimate = picked
        Haptics.play(.dragStep)
    }
}

extension NewItemDragOverlay {
    @ViewBuilder fileprivate var estimate: some View {
        if let minutes = drag.newItemEstimate {
            let label = rules.timeEstimates.first { $0.minutes == minutes }?.label
            Text(verbatim: label.map(L10n.string) ?? L10n.format("estimate.minutes", minutes))
                .font(tokens.font(.chip))
                .foregroundStyle(tokens.color(.primaryText))
                .chipInsets()
                .systemLook(.floatingCapsule)
                .fixedSize()
        }
    }
}

/// The "+" in its round glass.
private struct NewItemBubble: View {
    @Environment(\.tokens) private var tokens
    @Environment(AppModel.self) private var model

    var body: some View {
        Image(systemName: model.tabBarSymbols.newItem)
            .font(tokens.font(.tabIcon))
            .foregroundStyle(tokens.color(.primaryText))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .systemLook(.newItemBubble)
            // Outside the glass: what the glass draws takes no touches by itself.
            .contentShape(Circle())
    }
}

/// The "+" under the finger, over everything on the screen, while it is dragged; left of it the estimate a second
/// finger picked.
struct NewItemDragOverlay: View {
    @Environment(TaskDragState.self) private var drag
    @Environment(\.rules) private var rules
    @Environment(\.tokens) private var tokens

    var body: some View {
        if let point = drag.newItemPoint {
            GeometryReader { geometry in
                let origin = geometry.frame(in: .global).origin
                NewItemBubble()
                    .frame(width: drag.newItemSize.width, height: drag.newItemSize.height)
                    // Left of the "+", where the hand dragging it does not cover it.
                    .overlay(alignment: .leading) {
                        estimate.alignmentGuide(.leading) { $0[.trailing] + tokens.space(.chipGap) }
                    }
                    .position(x: point.x - origin.x, y: point.y - origin.y)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
