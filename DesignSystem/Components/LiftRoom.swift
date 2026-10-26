import SwiftUI

extension View {
    /// Lets rows of this scroll view draw over the screen margins beside it (a long-pressed plate grows
    /// past the column edge), while it still clips at its top and bottom. `extraTop`: room above the content for
    /// something laid over it (the all-day strip).
    func liftRoom(extraTop: CGFloat = 0) -> some View {
        modifier(LiftRoom(extraTop: extraTop))
    }
}

private struct LiftRoom: ViewModifier {
    @Environment(\.tokens) private var tokens
    let extraTop: CGFloat

    func body(content: Content) -> some View {
        // Sideways the rows (and their lift shadow) may cover the margins and the next column; at the top the first row
        // starts a shadow's height down, so its shadow fits too.
        content
            .contentMargins(.top, tokens.space(.liftShadow) + extraTop, for: .scrollContent)
            .scrollClipDisabled()
            .mask(Rectangle().padding(.horizontal, -tokens.size(.liftOverhang)))
    }
}
