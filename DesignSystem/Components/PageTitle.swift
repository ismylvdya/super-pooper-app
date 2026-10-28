import SwiftUI

extension View {
    /// On the scroll view (or list): keeps `isVisible` true while the large page title at the top of its content
    /// (`titleHeight` points with its top padding) still shows at least `largeTitleVisible` of itself.
    /// Read from the scroll offset, so a page that opens shows no bar title for a moment, and list rows that are
    /// reused do not lose it.
    func tracksLargeTitle(_ isVisible: Binding<Bool>, titleHeight: CGFloat) -> some View {
        modifier(LargeTitleTracking(isVisible: isVisible, titleHeight: titleHeight))
    }

    /// The page title in the navigation bar: clear while the large title is on screen, shown once it scrolls
    /// away (shrinking to fit between the bar buttons).
    func barTitle(_ title: String, isHidden: Bool) -> some View {
        modifier(BarTitle(title: title, isHidden: isHidden))
    }
}

private struct LargeTitleTracking: ViewModifier {
    @Environment(\.tokens) private var tokens
    @Binding var isVisible: Bool
    let titleHeight: CGFloat

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: Bool.self) { geometry in
            // Not measured yet: the page has just opened with its title on screen.
            titleHeight == 0 || geometry.contentOffset.y + geometry.contentInsets.top < titleHeight * (1 - tokens.opacity(.largeTitleVisible))
        } action: { _, visible in
            guard visible != isVisible else { return }
            withAnimation(.easeInOut(duration: tokens.duration(.titleColorAnimation))) { isVisible = visible }
        }
    }
}

private struct BarTitle: ViewModifier {
    @Environment(\.tokens) private var tokens
    let title: String
    let isHidden: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(tokens.font(.navTitle))
                        .lineLimit(1)
                        .minimumScaleFactor(tokens.size(.navTitleMin) / tokens.uiFont(.navTitle).pointSize)
                        .foregroundStyle(isHidden ? Color.clear : tokens.color(.primaryText))
                }
            }
    }
}
