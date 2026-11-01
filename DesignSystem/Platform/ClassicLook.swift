import SwiftUI

/// The iOS 18 look of `SystemLook`: the bar material, a regular material, the banner card with its shadow.
struct ClassicLook: ViewModifier {
    @Environment(\.tokens) private var tokens
    let look: SystemLook

    func body(content: Content) -> some View {
        switch look {
        case .barCapsule:
            content.background(.bar, in: Capsule())
        case .floatingCapsule:
            content.background(.regularMaterial, in: Capsule())
        case .bannerCard:
            content
                .background(tokens.color(.bannerBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.banner), style: .continuous))
                .shadow(color: tokens.color(.shadow).opacity(tokens.opacity(.bannerShadow)), radius: tokens.size(.bannerShadowRadius),
                        y: tokens.size(.bannerShadowY))
        }
    }
}
