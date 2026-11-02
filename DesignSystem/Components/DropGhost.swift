import SwiftUI

extension View {
    /// The faint copy of a dragged plate where it would land (`opacity.dropGhost`): seen, but not touched or read out. The
    /// pool's gap and the timeline's landing spot draw it; grouped lists show their own cell in the gap the same way
    /// (`ListLiftDelegates.showGhost`).
    func dropGhost(_ isGhost: Bool = true) -> some View {
        modifier(DropGhost(isGhost: isGhost))
    }
}

private struct DropGhost: ViewModifier {
    @Environment(\.tokens) private var tokens
    let isGhost: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isGhost ? tokens.opacity(.dropGhost) : 1)
            .allowsHitTesting(!isGhost)
            .accessibilityHidden(isGhost)
    }
}
