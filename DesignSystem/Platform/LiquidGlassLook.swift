#if compiler(>=6.2)
import SwiftUI

/// The iOS 26 look of `SystemLook`: Liquid Glass surfaces and the system's scroll edge effect under the bars.
/// Compiled only with the iOS 26 SDK (Xcode 26): keep it this small, every line here is unchecked on an older Mac.
@available(iOS 26.0, *)
struct LiquidGlassLook: ViewModifier {
    @Environment(\.tokens) private var tokens
    let look: SystemLook

    func body(content: Content) -> some View {
        switch look {
        case .barCapsule:
            content.glassEffect(.regular.interactive(), in: Capsule())
        case .newItemBubble:
            // Not interactive: that glass takes the touch for itself, and a swipe from the "+" must move it at once.
            content.glassEffect(.regular, in: Circle())
        case .floatingCapsule:
            content.glassEffect(.regular, in: Capsule())
        case .bannerCard:
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: tokens.bannerPlacement.radius, style: .continuous))
        case .scrollUnderBars(let edges):
            content.scrollEdgeEffectStyle(.soft, for: edges)
        case .fadeUnderBar:
            content.hidden()
        }
    }
}
#endif
