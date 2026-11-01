import SwiftUI

/// The looks the system design decides: how a surface or a scroll edge is drawn next to the system's own bars and
/// banners. As on iOS 18 (`ClassicLook`: materials, a card with a shadow, hand-made fades) or, built with the iOS 26 SDK
/// and running there, as Liquid Glass (`LiquidGlassLook`). Every such look goes through `systemLook(_:)`, which picks one
/// in one place.
enum SystemLook {
    /// The capsule of the system bar buttons and tab bar, around the bars the app draws itself (lying sideways).
    case barCapsule
    /// A capsule floating over a list, not a control (the pool's "+N more").
    case floatingCapsule
    /// A banner's card over the screen.
    case bannerCard
    /// A scroll view whose `edges` lie under a system bar (the tab bar upright): from iOS 26 the system's scroll edge
    /// effect fades them.
    case scrollUnderBars(Edge.Set)
    /// The hand-made fade at a scroll edge under a system bar: the system's scroll edge effect takes its place on iOS 26,
    /// so the edge is not faded twice.
    case fadeUnderBar
}

extension View {
    func systemLook(_ look: SystemLook) -> some View {
        modifier(SystemLookModifier(look: look))
    }
}

/// The one place that chooses between the two looks.
private struct SystemLookModifier: ViewModifier {
    let look: SystemLook

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        // The switch line (docs/IOS26-BUILD.md): with iOS 26 as the minimum it may become `content.modifier(LiquidGlassLook(look: look))`.
        if #available(iOS 26.0, *) { content.modifier(LiquidGlassLook(look: look)) } else { content.modifier(ClassicLook(look: look)) }
        #else
        content.modifier(ClassicLook(look: look))
        #endif
    }
}
