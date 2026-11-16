import SwiftUI

/// Dropping on the pool: rows make room under the finger and the task joins the section whose header is above it; a
/// task from the timeline loses its time, a habit's block leaves today's timeline, a task from a backlog page comes into
/// the day. A section dragged by its header goes before or after the others whole. What cannot land here shows no sign
/// while it is held; let go, it is refused with a banner (`onRefused`).
@MainActor
struct PoolDropDelegate: DropDelegate {
    let drag: TaskDragState
    let animation: Animation
    let layout: () -> PoolDropLayout
    /// Whether the dragged item can land here from where it came.
    let canDrop: (DayItem, TaskDragState.Source) -> Bool
    let onDrop: (DayItem, TaskDragState.Source, [String], String?) -> Void
    let onSectionDrop: (String, [String]) -> Void
    let onRefused: (DayItem) -> Void
    /// Where a task let go over the pool's right part would stand as a subtask of the row above it (`NewItemNesting`);
    /// `.top` keeps its parent as it is.
    var nesting: (_ order: [String], _ dragged: String, _ x: Double) -> NewItemNesting.Spot = { _, _, _ in .top }
    var onNest: (DayItem, NewItemNesting.Spot) -> Void = { _, _ in }

    /// A section's header, or a task when `canDrop` says so.
    func accepts() -> Bool {
        if drag.section != nil { return true }
        return drag.item.map { canDrop($0, drag.source) } ?? false
    }

    func dropEntered(info: DropInfo) {
        drag.turnAfterStay(.block(.pool))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard accepts() else { return DropProposal(operation: .move) }
        let layout = layout()
        let moved: Bool
        if let section = drag.section {
            let order = SectionDropOrder.order(headers: layout.headers, dragged: section, at: info.location.y)
            moved = withAnimation(animation) { drag.hover(sectionOrder: order) }
        } else if let dragged = drag.draggedID {
            let drop = PoolDropOrder.drop(rows: layout.rows, all: layout.all, headers: layout.headers, inSections: layout.inSections, dragged: dragged, at: info.location.y)
            let spot = drag.source == .pool || drag.source.isBacklog ? nesting(drop.order, dragged, Double(info.location.x)) : .top
            let nested = spot != drag.newItemSpot
            moved = withAnimation(animation) {
                if nested { drag.newItemSpot = spot }
                return drag.hover(poolOrder: drop.order, section: drop.section) || nested
            }
        } else {
            return DropProposal(operation: .move)
        }
        if moved { Haptics.play(.dragStep) }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        drag.cancelTurn(.block(.pool))
        withAnimation(animation) { drag.leavePool() }
    }

    func performDrop(info: DropInfo) -> Bool {
        let layout = layout()
        if let section = drag.section {
            let order = drag.sectionOrder ?? SectionDropOrder.order(headers: layout.headers, dragged: section, at: info.location.y)
            drag.end()
            onSectionDrop(section, order)
            return true
        }
        guard let item = drag.item else { return false }
        guard accepts() else {
            drag.end()
            onRefused(item)
            return true
        }
        let dragged = item.id
        let fresh = PoolDropOrder.drop(rows: layout.rows, all: layout.all, headers: layout.headers, inSections: layout.inSections, dragged: dragged, at: info.location.y)
        let order = drag.poolOrder ?? fresh.order
        let section = drag.poolOrder != nil ? drag.poolSection : fresh.section
        let source = drag.source
        let spot = drag.newItemSpot
        drag.end()
        if spot.parent != nil { onNest(item, spot) } else { onDrop(item, source, order, section) }
        return true
    }
}

/// The pool's rows and section headers as they stood when the drag reached it.
struct PoolDropLayout {
    /// The rows and headers on screen, where they stand.
    var rows: [PoolDropOrder.Row] = []
    var headers: [SectionDropOrder.Header] = []
    /// Every row in the pool's order, those scrolled away too.
    var all: [String]?
    /// The pool has section headers, on screen or not.
    var inSections = false
}

extension PoolDropLayout {
    /// The same layout after the list scrolled: everything stands `delta` further down the screen.
    func shifted(by delta: CGFloat) -> PoolDropLayout {
        var layout = self
        layout.rows = rows.map { PoolDropOrder.Row(id: $0.id, midY: $0.midY + Double(delta), section: $0.section) }
        layout.headers = headers.map { SectionDropOrder.Header(id: $0.id, midY: $0.midY + Double(delta)) }
        return layout
    }

    /// A row scrolled into sight during the drag joins the layout where it would stand without the gap: `lift` is how
    /// far the gap pushed it down (nothing above the gap).
    mutating func add(row id: String, midY: CGFloat, section: String?, lift: CGFloat) {
        guard !rows.contains(where: { $0.id == id }) else { return }
        rows.append(PoolDropOrder.Row(id: id, midY: Double(midY - lift), section: section))
    }

    mutating func add(header id: String, midY: CGFloat, lift: CGFloat) {
        guard !headers.contains(where: { $0.id == id }) else { return }
        headers.append(SectionDropOrder.Header(id: id, midY: Double(midY - lift)))
    }
}
