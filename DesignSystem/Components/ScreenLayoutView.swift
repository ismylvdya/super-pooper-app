import SwiftUI

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
