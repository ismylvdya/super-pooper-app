import SwiftUI

extension View {
    /// Text that stands back: a detail under a title, a hint, an empty list's line — in `font`, the secondary color.
    func secondaryText(_ font: FontToken = .caption) -> some View {
        modifier(SecondaryText(font: font))
    }
}

private struct SecondaryText: ViewModifier {
    @Environment(\.tokens) private var tokens
    let font: FontToken

    func body(content: Content) -> some View {
        content.font(tokens.font(font)).foregroundStyle(tokens.color(.secondaryText))
    }
}
