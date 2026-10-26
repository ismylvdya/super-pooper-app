import SwiftUI

/// The tab bar of the phone lying sideways: a column along the physical bottom, the tabs in the same physical order
/// as upright (Today nearest the physical left), so every tab stays under the same finger.
struct LandscapeTabBar: View {
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let bottom: HorizontalEdge

    var body: some View {
        VStack(spacing: 0) {
            ForEach(PhysicalBottom.physicalOrder(AppTab.allCases, bottom: bottom), id: \.self) { tab in
                Button { router.select(tab) } label: {
                    VStack(spacing: tokens.space(.badgeGap)) {
                        Image(systemName: icons[tab.icon]).font(tokens.font(.tabIcon))
                        Text(LocalizedStringKey(String("tab.") + tab.rawValue)).font(tokens.font(.tabLabel))
                    }
                    .foregroundStyle(router.tab == tab ? tokens.color(.accent) : tokens.color(.secondaryText))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(router.tab == tab ? .isSelected : [])
                .accessibilityIdentifier("landscapeTab.\(tab.rawValue)")
            }
        }
        .frame(width: tokens.size(.landscapeTabBarWidth))
        .background(.bar, ignoresSafeAreaEdges: [.vertical, bottom == .trailing ? .trailing : .leading])
        .overlay(alignment: bottom == .trailing ? .leading : .trailing) {
            Rectangle().fill(tokens.color(.timelineGrid)).frame(width: tokens.size(.tabBarSeparator))
        }
    }
}
