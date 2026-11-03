import SwiftUI

/// Renders a `ScreenLayout`: asks the registry for each block by id. A paged layout shows `page`
/// (the first one in previews), moved by `pageDrag`; `onTurn` makes its visible edge turn the page; `edgeInset` is
/// the margin between the layout and the screen's edge, which a page behind the leading edge shows in too.
struct ScreenLayoutView<Block: View>: View {
    @Environment(\.screenLayoutMetrics) private var metrics
    let layout: ScreenLayout
    var page = 0
    var pageDrag: CGFloat = 0
    var edgeInset: CGFloat = 0
    var onTurn: ((Int) -> Void)?
    @ViewBuilder let block: (TodayBlockID) -> Block

    var body: some View {
        if layout.isPaged {
            PagedStack(pages: layout.blocks.map(\.block), spacing: metrics.spacing(of: layout),
                       peeks: layout.blocks.map { metrics.peek(of: $0, in: layout, edgeInset: edgeInset) }, edgeInset: edgeInset,
                       page: page, drag: pageDrag, edgeLabel: TodayPageEdge.label, onTurn: onTurn, content: block)
        } else {
            WeightedStack(axis: layout.axis, spacing: metrics.spacing(of: layout), slots: layout.blocks) {
                ForEach(Array(layout.blocks.enumerated()), id: \.element.block) { index, slot in
                    block(slot.block).zIndex(LiftLayer.block(at: index, of: layout.blocks.count))
                }
            }
        }
    }
}

/// What the edge of a block's page says it turns to.
enum TodayPageEdge {
    static func label(_ block: TodayBlockID) -> Text {
        Text(block == .timeline ? "today.page.timeline" : "today.page.pool")
    }
}
