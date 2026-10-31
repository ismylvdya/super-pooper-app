import SwiftUI

/// Lays out blocks along one axis: `fit` blocks get their ideal length, `fill` blocks share the
/// rest by weight. Driven by `ScreenLayout` data.
struct WeightedStack: Layout {
    let axis: ScreenLayout.Axis
    let spacing: CGFloat
    let slots: [ScreenLayout.Slot]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let total = axis == .vertical ? bounds.height : bounds.width
        let cross = axis == .vertical ? bounds.width : bounds.height
        let gaps = spacing * CGFloat(max(subviews.count - 1, 0))

        var lengths = [CGFloat](repeating: 0, count: subviews.count)
        var fitTotal: CGFloat = 0
        for index in subviews.indices where size(index) == .fit {
            let ideal = axis == .vertical
                ? subviews[index].sizeThatFits(ProposedViewSize(width: cross, height: nil)).height
                : subviews[index].sizeThatFits(ProposedViewSize(width: nil, height: cross)).width
            lengths[index] = min(ideal, total)
            fitTotal += lengths[index]
        }
        let weights = subviews.indices.map { size($0) == .fill ? (slot(at: $0)?.weight ?? 1) : 0 }
        let weightSum = weights.reduce(0, +)
        let remaining = max(total - fitTotal - gaps, 0)
        for index in subviews.indices where size(index) == .fill {
            lengths[index] = weightSum > 0 ? remaining * weights[index] / weightSum : 0
        }

        var cursor = axis == .vertical ? bounds.minY : bounds.minX
        for index in subviews.indices {
            let origin = axis == .vertical ? CGPoint(x: bounds.minX, y: cursor) : CGPoint(x: cursor, y: bounds.minY)
            let size = axis == .vertical ? CGSize(width: cross, height: lengths[index]) : CGSize(width: lengths[index], height: cross)
            subviews[index].place(at: origin, proposal: ProposedViewSize(size))
            cursor += lengths[index] + spacing
        }
    }

    /// A view beyond the layout's slots fills like a slot of weight 1.
    private func size(_ index: Int) -> ScreenLayout.Size { slot(at: index)?.size ?? .fill }

    private func slot(at index: Int) -> ScreenLayout.Slot? { index < slots.count ? slots[index] : nil }
}

/// Renders a `ScreenLayout`: asks the registry for each block by id. A paged layout shows `page`
/// (the first one in previews), moved by `pageDrag`; `onTurn` makes its visible edge turn the page; `edgeInset` is
/// the margin between the layout and the screen's edge, which a page behind the leading edge shows in too.
struct ScreenLayoutView<Block: View>: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.chipOrder) private var chipOrder
    let layout: ScreenLayout
    var page = 0
    var pageDrag: CGFloat = 0
    var edgeInset: CGFloat = 0
    var onTurn: ((Int) -> Void)?
    @ViewBuilder let block: (TodayBlockID) -> Block

    var body: some View {
        if layout.isPaged {
            PagedStack(slots: layout.blocks, spacing: spacing, peeks: layout.blocks.map(peek), edgeInset: edgeInset, page: page,
                       drag: pageDrag, onTurn: onTurn, block: block)
        } else {
            WeightedStack(axis: layout.axis, spacing: spacing, slots: layout.blocks) {
                ForEach(layout.blocks, id: \.block) { slot in block(slot.block) }
            }
        }
    }

    /// A chip peek is counted from the screen's edge: the row plate's right inset and that part of the rows' last chip
    /// (in the user's chip order).
    private func peek(_ slot: ScreenLayout.Slot) -> CGFloat {
        if let part = slot.peekChip {
            let chip = chipOrder.last.map { Chip.width(of: $0.icon, tokens: tokens, icons: icons) } ?? 0
            return tokens.rowPlateTrailingInset + chip * part - edgeInset
        }
        return layout.peek.flatMap(SizeToken.init(rawValue:)).map(tokens.size) ?? 0
    }

    private var spacing: CGFloat {
        SpacingToken(rawValue: layout.spacing).map(tokens.space) ?? 0
    }
}
