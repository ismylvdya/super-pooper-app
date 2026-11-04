import SwiftUI

extension View {
    /// Lying sideways (`bottom`: the screen's edge at the phone's physical bottom) a quarter turn back, so it stands on the
    /// physical screen as it does upright, and takes the room it takes that way. Upright it is as it is.
    func quarterTurned(_ bottom: HorizontalEdge?) -> some View {
        modifier(QuarterTurned(bottom: bottom))
    }
}

private struct QuarterTurned: ViewModifier {
    let bottom: HorizontalEdge?

    @ViewBuilder func body(content: Content) -> some View {
        if let bottom {
            QuarterTurnLayout {
                content
                    .fixedSize()
                    .rotationEffect(.degrees(bottom == .trailing ? -90 : 90))
            }
        } else {
            content
        }
    }
}

/// Lays its view out with width and height swapped.
private struct QuarterTurnLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let size = subviews.first?.sizeThatFits(.unspecified) else { return .zero }
        return CGSize(width: size.height, height: size.width)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
    }
}
