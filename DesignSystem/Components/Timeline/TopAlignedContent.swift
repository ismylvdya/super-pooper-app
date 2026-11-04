import SwiftUI

/// Puts its one subview at the top of the space it gets, whatever its height: what does not fit in a short block goes
/// past its bottom edge only, so the title always stays in sight.
struct TopAlignedContent: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews.first?.sizeThatFits(proposal) ?? .zero
        return CGSize(width: proposal.width ?? size.width, height: proposal.height ?? size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        subview.place(at: CGPoint(x: bounds.minX, y: bounds.minY), proposal: ProposedViewSize(width: bounds.width, height: size.height))
    }
}
