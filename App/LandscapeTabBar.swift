import SwiftUI

/// The tab bar of the phone lying sideways: the same glass capsule as the system one upright, standing along the
/// physical bottom, the tabs in the same physical order as upright (Today nearest the physical left), so every tab
/// stays under the same finger.
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
                        // The symbol as `icons.json` names it and the small label, as in the tab bar upright.
                        TabIconImage.image(icons[tab.icon], font: tokens.uiFont(.tabIcon), others: AppTab.allCases.map { icons[$0.icon] },
                                           matching: .width)
                            .font(tokens.font(.tabIcon))
                        // Centered in the bar when it fits; a longer label starts at the left and fades.
                        ViewThatFits(in: .horizontal) {
                            Text(L10n.string(String("tab.") + tab.rawValue)).font(tokens.font(.tabLabel)).lineLimit(1).fixedSize()
                            FadingText(text: L10n.string(String("tab.") + tab.rawValue), font: tokens.font(.tabLabel),
                                       lineHeight: tokens.uiFont(.tabLabel).lineHeight)
                        }
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, tokens.space(.tabBarInner))
                    .foregroundStyle(tokens.color(.primaryText))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tokens.color(.chipBackground).opacity(router.tab == tab ? 1 : 0), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(router.tab == tab ? .isSelected : [])
                .accessibilityIdentifier("landscapeTab.\(tab.rawValue)")
            }
        }
        .padding(tokens.space(.tabBarInner))
        .frame(width: tokens.size(.landscapeTabBarWidth))
        .glassBubble()
        // Measured from the screen edges, not the safe area, so it sits as far from the edges as upright in both turns
        // (the root lays the column out from the screen edge at the physical bottom).
        .padding(.vertical, tokens.space(.landscapeBarInset))
        .padding(side, tokens.space(.landscapeBarInset))
        .ignoresSafeArea(.container, edges: .vertical)
    }

    /// The screen edge at the physical bottom.
    private var side: Edge.Set { bottom == .trailing ? .trailing : .leading }
}
