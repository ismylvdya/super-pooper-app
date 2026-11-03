import SwiftUI

extension View {
    /// On the scroll view (or list) whose content starts with a `LargePageTitle` `titleHeight` high: once the large
    /// title scrolls away, `title` shows in the navigation bar.
    func titleScrollsIntoBar(_ title: String, titleHeight: CGFloat) -> some View {
        modifier(TitleIntoBar(title: title, titleHeight: titleHeight))
    }
}

private struct TitleIntoBar: ViewModifier {
    let title: String
    let titleHeight: CGFloat
    @State private var isLargeTitleVisible = true

    func body(content: Content) -> some View {
        content
            .modifier(LargeTitleTracking(isVisible: $isLargeTitleVisible, titleHeight: titleHeight))
            .modifier(BarTitle(title: title, isHidden: isLargeTitleVisible))
    }
}

/// Keeps `isVisible` true while the large title (`titleHeight` points with its top padding) still shows at least
/// `largeTitleVisible` of itself. Read from the scroll offset, so a page that opens shows no bar title for a moment,
/// and list rows that are reused do not lose it.
private struct LargeTitleTracking: ViewModifier {
    @Environment(\.tokens) private var tokens
    @Binding var isVisible: Bool
    let titleHeight: CGFloat

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: Bool.self) { geometry in
            // Not measured yet: the page has just opened with its title on screen.
            titleHeight == 0 || geometry.contentOffset.y + geometry.contentInsets.top < titleHeight * (1 - tokens.ratio(.largeTitleVisible))
        } action: { _, visible in
            guard visible != isVisible else { return }
            withAnimation(.easeInOut(duration: tokens.duration(.titleColorAnimation))) { isVisible = visible }
        }
    }
}

/// The page title in the navigation bar: clear while the large title is on screen, shown once it scrolls away
/// (shrinking to fit between the bar buttons).
private struct BarTitle: ViewModifier {
    @Environment(\.tokens) private var tokens
    @Environment(\.physicalBottom) private var physicalBottom
    let title: String
    let isHidden: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Lying sideways the system centres it in the bar, off the page's middle: see below.
                ToolbarItem(placement: .principal) {
                    text.foregroundStyle(isHidden || physicalBottom != nil ? Color.clear : tokens.color(.primaryText))
                }
            }
            // On the page's own middle, as the large title it follows.
            .overlay(alignment: .top) {
                if physicalBottom != nil, !isHidden {
                    text
                        .foregroundStyle(tokens.color(.primaryText))
                        .frame(height: tokens.bar(.navigationBar))
                        .ignoresSafeArea(.container, edges: .top)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }

    private var text: some View {
        Text(title)
            .font(tokens.font(.navTitle))
            .lineLimit(1)
            .minimumScaleFactor(tokens.size(.navTitleMin) / tokens.uiFont(.navTitle).pointSize)
    }
}
