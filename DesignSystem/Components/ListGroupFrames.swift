import SwiftUI

/// Where the rows of the groups stand on screen and how far the list is scrolled. Written by the rows and the list,
/// read only by the backing: scrolling redraws the backing, not the list.
@MainActor
@Observable
final class ListGroupFrames {
    struct Row: Equatable {
        var frame: CGRect
        /// The row's place in its group, in the group's own order (not where a drag has moved it on screen).
        var index: Int
        var count: Int
        /// On screen now; a row out of sight keeps its last place but does not bound the backing.
        var isVisible = true

        var isFirst: Bool { index == 0 }
        var isLast: Bool { index == count - 1 }
    }

    private(set) var rows: [String: [String: Row]] = [:]
    /// The list's content offset: the rows move by it on screen, the content does not.
    private(set) var scrollOffset: CGFloat = 0
    /// The list's span on screen.
    private(set) var viewport: ClosedRange<CGFloat> = 0...0
    /// Where the rows stand across the list: the backings' sides — the list's sides inside its margins. Not taken from
    /// the rows: a row being swiped reports frames out to the side or wider than at rest, and a backing taken from one
    /// of those stayed shifted after the swipe.
    private(set) var columns: ClosedRange<CGFloat>?
    /// Each group's backing from the last moment the rows of every group stood in their order, in the list's content:
    /// kept while a row is lifted, dragged or moving aside — in its own group or another one (a row dragged into another
    /// group moves that group's rows aside too, sometimes all of them together).
    private(set) var heldSpans: [String: ListGroupGeometry.Span] = [:]
    /// How many views each row has on screen now.
    private var appearances: [String: Int] = [:]

    func set(_ row: Row?, group: String, id: String) {
        guard rows[group]?[id] != row else { return }
        rows[group, default: [:]][id] = row
        holdSpans()
    }

    /// The list's sides on screen and its margin on each side (`listGroupStyle`): the rows stand between.
    func setSides(_ sides: ClosedRange<CGFloat>, margin: CGFloat) {
        let inner = sides.lowerBound + margin
        let outer = max(sides.upperBound - margin, inner)
        guard columns != inner...outer else { return }
        columns = inner...outer
    }

    /// A row's view came or went. A list that gets a new identity (search closed) has the new row appear before the old
    /// one disappears: the row is visible while any of its views is.
    func setVisible(_ isVisible: Bool, group: String, id: String) {
        let key = group + "\u{0}" + id
        appearances[key, default: 0] += isVisible ? 1 : -1
        let shown = appearances[key, default: 0] > 0
        guard var row = rows[group]?[id], row.isVisible != shown else { return }
        row.isVisible = shown
        set(row, group: group, id: id)
    }

    /// A row's place in its group changed without moving it on screen (another row came or went).
    func setPlace(index: Int, count: Int, group: String, id: String) {
        guard var row = rows[group]?[id], row.index != index || row.count != count else { return }
        row.index = index
        row.count = count
        set(row, group: group, id: id)
    }

    /// A row moved to another group (Soon: a drag into another part of the day) leaves its old group's backing.
    func move(_ id: String, from old: String, to new: String, index: Int, count: Int) {
        guard var row = rows[old]?[id] else { return }
        set(nil, group: old, id: id)
        guard rows[new]?[id] == nil else { return }
        row.index = index
        row.count = count
        set(row, group: new, id: id)
    }

    func setScrollOffset(_ offset: CGFloat) {
        guard scrollOffset != offset else { return }
        scrollOffset = offset
        holdSpans()
    }

    func setViewport(_ viewport: ClosedRange<CGFloat>) {
        guard self.viewport != viewport else { return }
        self.viewport = viewport
        holdSpans()
    }

    /// The backing of a group on screen now: from its rows while the list rests, otherwise the one held.
    func plate(of group: String, overhang: CGFloat) -> CGRect? {
        let resting = restingSpan(of: group)
        guard var span = isResting ? resting : heldSpans[group] ?? resting else { return nil }
        if let columns {
            span.minX = columns.lowerBound
            span.width = columns.upperBound - columns.lowerBound
        }
        return ListGroupGeometry.plate(of: span, visible: viewport, overhang: overhang, offset: scrollOffset)
    }

    /// Every group with rows on screen has them in its order.
    private var isResting: Bool {
        rows.values.allSatisfy { group in
            let rows = Array(group.values)
            return !rows.contains(where: \.isVisible) || ListGroupGeometry.isResting(rows, visible: viewport)
        }
    }

    private func restingSpan(of group: String) -> ListGroupGeometry.Span? {
        ListGroupGeometry.restingSpan(of: Array((rows[group] ?? [:]).values), visible: viewport, offset: scrollOffset)
    }

    private func holdSpans() {
        guard isResting else { return }
        for group in rows.keys {
            if let span = restingSpan(of: group), heldSpans[group] != span { heldSpans[group] = span }
        }
    }
}
