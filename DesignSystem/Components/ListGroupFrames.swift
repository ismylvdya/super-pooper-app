import SwiftUI

/// Where the rows of the groups stand on screen. Written by the rows, read only by the backing: scrolling redraws
/// the backing, not the list.
@MainActor
@Observable
final class ListGroupFrames {
    struct Row: Equatable {
        var frame: CGRect
        var isFirst: Bool
        var isLast: Bool
        /// On screen now; a row out of sight keeps its last place but does not bound the backing.
        var isVisible = true
    }

    private(set) var rows: [String: [String: Row]] = [:]
    /// Each group's top while its rows stand in their slots, kept while one is lifted (`ListGroupGeometry.isResting`).
    private(set) var restingTops: [String: CGFloat] = [:]

    func set(_ row: Row?, group: String, id: String) {
        guard rows[group]?[id] != row else { return }
        rows[group, default: [:]][id] = row
        noteRestingTop(of: group)
    }

    func setVisible(_ isVisible: Bool, group: String, id: String) {
        guard var row = rows[group]?[id], row.isVisible != isVisible else { return }
        row.isVisible = isVisible
        rows[group]?[id] = row
        noteRestingTop(of: group)
    }

    /// A row became or stopped being its group's first or last without moving (another row came or went).
    func setEnds(isFirst: Bool, isLast: Bool, group: String, id: String) {
        guard var row = rows[group]?[id], row.isFirst != isFirst || row.isLast != isLast else { return }
        row.isFirst = isFirst
        row.isLast = isLast
        set(row, group: group, id: id)
    }

    /// A row moved to another group (This week: a drag into another part of the day) leaves its old group's backing.
    func move(_ id: String, from old: String, to new: String, isFirst: Bool, isLast: Bool) {
        guard var row = rows[old]?[id] else { return }
        set(nil, group: old, id: id)
        guard rows[new]?[id] == nil else { return }
        row.isFirst = isFirst
        row.isLast = isLast
        set(row, group: new, id: id)
    }

    private func noteRestingTop(of group: String) {
        let shown = (rows[group] ?? [:]).values.filter(\.isVisible)
        guard ListGroupGeometry.isResting(Array(shown)), let first = shown.first(where: \.isFirst) else { return }
        if restingTops[group] != first.frame.minY { restingTops[group] = first.frame.minY }
    }
}
