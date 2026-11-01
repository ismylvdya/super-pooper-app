import SwiftUI

/// The backing of one group from its rows on screen: from the first row's top, as tall as all its rows together —
/// so a row dragged away (the last one too) never shrinks it — and at least to the last row's bottom. While a row is
/// lifted the top stays where the rows stood (`restingTop`): a lifted first row moves with the finger, its slot does not.
/// A first or last row out of sight (a list only lays out what shows) leaves that side open past `visible`.
enum ListGroupGeometry {
    /// Rows closer than this touch (frames come in fractions of a point).
    private static let seam: CGFloat = 1

    static func plate(of rows: [ListGroupFrames.Row], visible: ClosedRange<CGFloat>, overhang: CGFloat,
                      restingTop: CGFloat? = nil) -> CGRect? {
        let shown = rows.filter(\.isVisible)
        guard let any = shown.first else { return nil }
        let first = shown.first { $0.isFirst }
        let last = shown.first { $0.isLast }
        let lifted = first != nil && !isResting(shown)
        let top = (lifted ? restingTop : nil) ?? first?.frame.minY ?? visible.lowerBound - overhang
        var bottom = last?.frame.maxY ?? visible.upperBound + overhang
        if first != nil, last != nil { bottom = max(bottom, top + shown.map(\.frame.height).reduce(0, +)) }
        guard bottom > top else { return nil }
        return CGRect(x: any.frame.minX, y: top, width: any.frame.width, height: bottom - top)
    }

    /// The rows stand one under another with no gap: nothing is lifted or moving aside.
    static func isResting(_ rows: [ListGroupFrames.Row]) -> Bool {
        let ordered = rows.map(\.frame).sorted { $0.minY < $1.minY }
        return zip(ordered, ordered.dropFirst()).allSatisfy { abs($1.minY - $0.maxY) < seam }
    }
}
