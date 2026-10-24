import SwiftUI

extension View {
    /// Lets rows of this scroll view draw over the screen margins beside it (a long-pressed plate grows
    /// past the column edge), while it still clips at its top and bottom.
    func liftRoom() -> some View {
        modifier(LiftRoom())
    }
}

private struct LiftRoom: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        // Sideways the rows (and their lift shadow) may cover the screen margin; at the top the first row
        // starts a shadow's height down, so its shadow fits too.
        content
            .contentMargins(.top, tokens.space(.liftShadow), for: .scrollContent)
            .scrollClipDisabled()
            .mask(Rectangle().padding(.horizontal, -tokens.space(.screenHorizontal)))
    }
}
