import SwiftUI

extension View {
    /// Keeps `isVisible` true while most of the large page title is on screen (animated like the bar title).
    func tracksLargeTitle(_ isVisible: Binding<Bool>) -> some View {
        modifier(LargeTitleTracking(isVisible: isVisible))
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

    func body(content: Content) -> some View {
        content.onScrollVisibilityChange(threshold: tokens.opacity(.largeTitleVisible)) { visible in
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
