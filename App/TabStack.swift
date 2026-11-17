import SwiftUI

/// One tab's navigation stack, a view of its own: a page pushed or popped redraws this stack only. Read in the root
/// view, the path would redraw the root, whose environment (tokens, rules, looks) reaches every view of the app, and each
/// push or pop would stall on that.
struct TabStack<Root: View, Destination: View>: View {
    @Environment(\.tokens) private var tokens
    let tab: AppTab
    let router: Router
    /// Where the landscape tab bar stands (none upright), and the room the stack keeps from it.
    let physicalBottom: HorizontalEdge?
    let isKeyboardUp: Bool
    let safeArea: EdgeInsets
    @ViewBuilder let root: () -> Root
    @ViewBuilder let destination: (Route) -> Destination

    var body: some View {
        NavigationStack(path: Binding(get: { router.paths[tab] ?? [] }, set: { router.paths[tab] = $0 })) {
            root()
                .systemTabBar(isShown: physicalBottom == nil)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                        .syncsOnPull()
                        .systemTabBar(isShown: physicalBottom == nil)
                }
        }
        .padding(physicalBottom == .leading ? .leading : .trailing, landscapeRoom)
        // The room is the screen's own background, as on Tasks: no bar of the tab view's shows through it.
        .screenBackground()
        // The tab bar's own color stops at the bar.
        .tint(tokens.color(.accent))
    }

    /// The room the stack keeps from the landscape tab bar. It stands inside the safe area, so that part of the room is
    /// there already. Tasks' first page has no system bar and keeps the room itself.
    private var landscapeRoom: CGFloat {
        guard let physicalBottom, !isKeyboardUp else { return 0 }
        if tab == .today, (router.paths[tab] ?? []).isEmpty { return 0 }
        return max(tokens.bar(.landscapeTabBarRoom) - (physicalBottom == .leading ? safeArea.leading : safeArea.trailing), 0)
    }
}

private extension View {
    /// Lying sideways the app draws its own tab bar along the physical bottom instead of the system one.
    func systemTabBar(isShown: Bool) -> some View {
        toolbar(isShown ? .visible : .hidden, for: .tabBar)
    }
}
