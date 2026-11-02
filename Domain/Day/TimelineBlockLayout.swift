import Foundation

/// Where the blocks of a timeline column go, in points from the top of its window. An event stands exactly from its start
/// to its end. A task or reminder gets at least its minimum height (its title and chip lines). A later block that starts
/// below an earlier one's title lies over it indented, or shares the width in columns when it starts too close for that,
/// as in Calendar (`CascadeAssigner`). Only short tasks stack: a task starting inside the title of an earlier task that
/// has no height beyond its minimum is drawn right under it, edge to edge, so short chains read top to bottom.
struct TimelineBlockLayout: Sendable {
    struct Placement: Identifiable, Sendable {
        let slot: TimelineSlot
        let top: Double
        let height: Double
        let indent: Int
        let column: Int
        let columnCount: Int

        var id: String { slot.id }
        var bottom: Double { top + height }

        /// Where the block starts and how wide it is in a column `width` wide, indented `indentStep` per step.
        func horizontal(in width: Double, indentStep: Double) -> (x: Double, width: Double) {
            let inset = min(Double(indent) * indentStep, width)
            let columnWidth = (width - inset) / Double(columnCount)
            return (inset + Double(column) * columnWidth, columnWidth)
        }
    }

    let window: TimelineWindow
    let hourHeight: Double
    /// One line of an event's title: the room a later block leaves under an event's top to keep it readable.
    let minimumEventHeight: Double
    /// Tasks and reminders are at least this tall (their title and chip lines).
    let minimumTaskHeight: Double
    /// The room a block's title needs below its top, as a share of its minimum height: a block starting closer under it
    /// stands beside it (or, both being short tasks, under it) instead of over it.
    let titleRoomShare: Double

    /// The blocks inside the window, earliest first (the longer of two starting together first).
    func place(_ slots: [TimelineSlot]) -> [Placement] {
        let visible = slots.filter { $0.end > window.start && $0.start < window.end }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }
        var extents: [CascadeAssigner.Block] = []
        var stacksOthers: [Bool] = []
        for slot in visible {
            var top = y(max(slot.start, window.start))
            let span = y(min(slot.end, window.end)) - top
            let height = slot.isEvent ? span : max(span, minimumTaskHeight)
            if !slot.isEvent { top = stackedTop(top, under: extents, stacking: stacksOthers) }
            extents.append(CascadeAssigner.Block(top: top, bottom: top + height, titleRoom: minimumHeight(of: slot) * titleRoomShare))
            stacksOthers.append(!slot.isEvent && span <= minimumTaskHeight)
        }
        return zip(visible, zip(extents, CascadeAssigner.assign(extents))).map { slot, pair in
            let (extent, placement) = pair
            return Placement(slot: slot, top: extent.top, height: extent.bottom - extent.top, indent: placement.indent,
                             column: placement.column, columnCount: placement.columnCount)
        }
    }

    /// Below every short task whose title a task starting at `top` would cover, again and again down the chain.
    private func stackedTop(_ top: Double, under extents: [CascadeAssigner.Block], stacking: [Bool]) -> Double {
        var top = top
        while let covered = extents.indices.first(where: { stacking[$0] && extents[$0].bottom > top && top < extents[$0].top + extents[$0].titleRoom }) {
            top = extents[covered].bottom
        }
        return top
    }

    private func y(_ date: Date) -> Double {
        window.offset(of: date, hourHeight: hourHeight)
    }

    private func minimumHeight(of slot: TimelineSlot) -> Double {
        slot.isEvent ? minimumEventHeight : minimumTaskHeight
    }
}

private extension TimelineSlot {
    var isEvent: Bool {
        if case .event = content { return true }
        return false
    }
}
