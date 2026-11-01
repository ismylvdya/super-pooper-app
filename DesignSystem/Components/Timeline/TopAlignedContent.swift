import SwiftUI

/// Puts its one subview at the top of the space it gets; one taller than that space is centred, overflowing both edges
/// alike. An event's title and time stand at the top of a tall block, and a block of the minimum height (shorter than
/// its two lines) shows them as it always did.
struct TopAlignedContent: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews.first?.sizeThatFits(proposal) ?? .zero
        return CGSize(width: proposal.width ?? size.width, height: proposal.height ?? size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        let overflow = max(size.height - bounds.height, 0)
        subview.place(at: CGPoint(x: bounds.minX, y: bounds.minY - overflow / 2),
                      proposal: ProposedViewSize(width: bounds.width, height: size.height))
    }
}
