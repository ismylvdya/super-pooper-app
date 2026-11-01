import SwiftUI

/// The backing of one group: from the first row's top to the last row's bottom, taken while the rows stand in the
/// group's order, one under another. A row lifted for a drag does not leave its slot empty: the list moves its (hidden)
/// cell to where it would drop and the other rows aside, so the rows still touch but no longer stand in their order.
/// Until they do again, the backing stays where it was, in the list's content (it scrolls with the list) — its top
/// where the first row stood, its height that of all the rows. A first or last row out of sight (a list only lays
/// out what shows) leaves that side open past the screen.
enum ListGroupGeometry {
    /// Rows closer than this touch (frames come in fractions of a point).
    private static let seam: CGFloat = 1

    /// A group's backing in the list's content: its top and bottom are nil while open (that end row is out of sight).
    struct Span: Equatable {
        var minX: CGFloat
        var width: CGFloat
        var top: CGFloat?
        var bottom: CGFloat?
    }

    /// The group's backing in the list's content while its rows rest in their slots; nil while they do not.
    static func restingSpan(of rows: [ListGroupFrames.Row], visible: ClosedRange<CGFloat>, offset: CGFloat) -> Span? {
        let shown = current(rows).filter(\.isVisible).sorted { $0.index < $1.index }
        guard let first = shown.first, let last = shown.last, isResting(rows, visible: visible) else { return nil }
        return Span(minX: first.frame.minX, width: first.frame.width,
                    top: first.isFirst ? first.frame.minY + offset : nil,
                    bottom: last.isLast ? last.frame.maxY + offset : nil)
    }

    /// Where a span stands on screen; an open side reaches `overhang` past the visible part, so no corner shows there.
    static func plate(of span: Span, visible: ClosedRange<CGFloat>, overhang: CGFloat, offset: CGFloat) -> CGRect? {
        let top = span.top.map { $0 - offset } ?? visible.lowerBound - overhang
        let bottom = span.bottom.map { $0 - offset } ?? visible.upperBound + overhang
        guard bottom > top else { return nil }
        return CGRect(x: span.minX, y: top, width: span.width, height: bottom - top)
    }

    /// The rows on screen stand in the group's order with nothing between them but the rows out of sight, and a row
    /// out of sight at either end is really past the edge of the list (not taken out of it by a drag).
    static func isResting(_ rows: [ListGroupFrames.Row], visible: ClosedRange<CGFloat>) -> Bool {
        let rows = current(rows)
        let byIndex = Dictionary(rows.map { ($0.index, $0) }) { kept, other in kept.isVisible ? kept : other }
        let shown = rows.filter(\.isVisible).sorted { $0.index < $1.index }
        guard let first = shown.first, let last = shown.last else { return false }
        for (upper, lower) in zip(shown, shown.dropFirst()) {
            // Two rows in one place: their new places are still coming in.
            guard lower.index > upper.index else { return false }
            let between = (upper.index + 1..<lower.index).compactMap { byIndex[$0]?.frame.height }
            guard between.count == lower.index - upper.index - 1 else { continue }
            if abs(lower.frame.minY - upper.frame.maxY - between.reduce(0, +)) >= seam { return false }
        }
        if let above = byIndex[first.index - 1], first.frame.minY - above.frame.height > visible.lowerBound + seam { return false }
        if let below = byIndex[last.index + 1], last.frame.maxY + below.frame.height < visible.upperBound - seam { return false }
        return true
    }

    /// The rows that belong to the group as it is now: the ones on screen, and the ones out of sight that know the
    /// group's count (a row whose note left the group keeps an old one).
    private static func current(_ rows: [ListGroupFrames.Row]) -> [ListGroupFrames.Row] {
        guard let count = rows.filter(\.isVisible).map(\.count).max() else { return [] }
        return rows.filter { $0.isVisible || ($0.count == count && $0.index < count) }
    }
}
