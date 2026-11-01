import Foundation

/// Where the blocks of a timeline column go, in points from the top of its window. Every block gets at least its
/// minimum height. A block that does not overlap an earlier one in time but would overlap it on screen is pushed below
/// it (so short chains read top to bottom); blocks that really overlap share the width in columns, as in Calendar.
struct TimelineBlockLayout: Sendable {
    struct Placement: Identifiable, Sendable {
        let slot: TimelineSlot
        let top: Double
        let height: Double
        let column: Int
        let columnCount: Int

        var id: String { slot.id }
        var bottom: Double { top + height }

        /// Where the block starts and how wide it is in a column `width` wide.
        func horizontal(in width: Double) -> (x: Double, width: Double) {
            let columnWidth = width / Double(columnCount)
            return (Double(column) * columnWidth, columnWidth)
        }
    }

    let window: TimelineWindow
    let hourHeight: Double
    /// At least one line of an event's title.
    let minimumEventHeight: Double
    /// Tasks and reminders may need more (their title and chip lines).
    let minimumTaskHeight: Double

    /// The blocks inside the window, earliest first (the longer of two starting together first).
    func place(_ slots: [TimelineSlot]) -> [Placement] {
        let visible = slots.filter { $0.end > window.start && $0.start < window.end }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }
        var extents: [(start: Double, end: Double)] = []
        for (index, slot) in visible.enumerated() {
            var top = y(max(slot.start, window.start))
            let height = max(y(min(slot.end, window.end)) - top, minimumHeight(of: slot))
            for earlier in visible.indices where earlier < index && visible[earlier].end <= slot.start {
                top = max(top, extents[earlier].end)
            }
            extents.append((top, top + height))
        }
        return zip(visible, zip(extents, ColumnAssigner.assign(extents))).map { slot, pair in
            let (extent, placement) = pair
            return Placement(slot: slot, top: extent.start, height: extent.end - extent.start, column: placement.column,
                             columnCount: placement.columnCount)
        }
    }

    private func y(_ date: Date) -> Double {
        window.offset(of: date, hourHeight: hourHeight)
    }

    private func minimumHeight(of slot: TimelineSlot) -> Double {
        switch slot.content {
        case .task, .reminder: minimumTaskHeight
        case .event: minimumEventHeight
        }
    }
}
