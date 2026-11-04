import SwiftUI

/// The tab bar of the phone lying sideways: the same glass capsule as the system one upright, standing along the
/// physical bottom, the tabs in the same physical order as upright (Today nearest the physical left), so every tab
/// stays under the same finger. The "+" bubble stands apart at its physical right end, as upright.
struct LandscapeTabBar: View {
    @Environment(Router.self) private var router
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.displayScale) private var displayScale
    let bottom: HorizontalEdge

    private enum Part: CaseIterable { case tabs, newItem }

    var body: some View {
        VStack(spacing: tokens.bar(.newItemBubbleGap)) {
            ForEach(PhysicalBottom.physicalOrder(Part.allCases, bottom: bottom), id: \.self) { part in
                switch part {
                case .tabs: tabs
                case .newItem:
                    NewItemButton().frame(width: tokens.bar(.landscapeTabBarWidth), height: tokens.bar(.landscapeTabBarWidth))
                }
            }
        }
        // Measured from the screen edges, not the safe area, so it sits as far from the edges as upright in both turns
        // (the root lays the column out from the screen edge at the physical bottom).
        .padding(.vertical, tokens.bar(.landscapeBarInset))
        .padding(side, tokens.bar(.landscapeBarInset))
        .ignoresSafeArea(.container, edges: .vertical)
    }

    private var tabs: some View {
        VStack(spacing: 0) {
            ForEach(PhysicalBottom.physicalOrder(AppTab.allCases, bottom: bottom), id: \.self) { tab in
                Button { router.select(tab) } label: {
                    VStack(spacing: tokens.bar(.tabIconLabelGap)) {
                        // The symbol as `icons.json` names it and the small label, as in the tab bar upright.
                        TabIconImage.image(model.tabBarSymbols.symbol(of: tab, isSelected: router.tab == tab), font: tokens.uiFont(.tabIcon),
                                           others: icons.otherTabSymbols(than: tab), matching: .width,
                                           fit: tokens.bar(.tabGlyphFit), scale: displayScale)
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
                    .padding(.horizontal, tokens.bar(.tabBarInner))
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
        .padding(tokens.bar(.tabBarInner))
        .frame(width: tokens.bar(.landscapeTabBarWidth))
        .systemLook(.barCapsule)
    }

    /// The screen edge at the physical bottom.
    private var side: Edge.Set { bottom == .trailing ? .trailing : .leading }
}
