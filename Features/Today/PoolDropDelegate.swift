import SwiftUI

/// Dropping on the pool: rows make room under the finger and the task joins the section whose header is above it; a
/// task from the timeline loses its time, a habit's block leaves today's timeline, a task from a backlog page comes into
/// the day. A section dragged by its header goes before or after the others whole. A "+" makes room as a task does and,
/// let go, opens the new task's page for that spot (`acceptsNewItem`: today's pool only).
@MainActor
struct PoolDropDelegate: DropDelegate {
    let drag: TaskDragState
    let animation: Animation
    let layout: () -> PoolDropLayout
    /// Whether the dragged item can land here from where it came.
    let canDrop: (DayItem, TaskDragState.Source) -> Bool
    let onDrop: (DayItem, TaskDragState.Source, [String], String?) -> Void
    let onSectionDrop: (String, [String]) -> Void
    let acceptsNewItem: Bool
    let onNewItemDrop: ([String], String?) -> Void

    func validateDrop(info: DropInfo) -> Bool { validate() }

    func validate() -> Bool {
        if drag.section != nil { return true }
        if drag.source == .newItem { return acceptsNewItem }
        return drag.item.map { canDrop($0, drag.source) } ?? false
    }

    func dropEntered(info: DropInfo) {
        drag.turn(.block(.pool))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let layout = layout()
        let moved: Bool
        if let section = drag.section {
            let order = SectionDropOrder.order(headers: layout.headers, dragged: section, at: info.location.y)
            moved = withAnimation(animation) { drag.hover(sectionOrder: order) }
        } else if let dragged = drag.draggedID {
            let drop = PoolDropOrder.drop(rows: layout.rows, headers: layout.headers, dragged: dragged, at: info.location.y)
            moved = withAnimation(animation) { drag.hover(poolOrder: drop.order, section: drop.section) }
        } else {
            return nil
        }
        if moved { Haptics.play(.dragStep) }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
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
        guard let dragged = drag.draggedID else { return false }
        let fresh = PoolDropOrder.drop(rows: layout.rows, headers: layout.headers, dragged: dragged, at: info.location.y)
        let order = drag.poolOrder ?? fresh.order
        let section = drag.poolOrder != nil ? drag.poolSection : fresh.section
        let item = drag.item
        let source = drag.source
        drag.end()
        if let item { onDrop(item, source, order, section) } else { onNewItemDrop(order, section) }
        return true
    }
}

/// The pool's rows and section headers as they stood when the drag reached it.
struct PoolDropLayout {
    var rows: [PoolDropOrder.Row] = []
    var headers: [SectionDropOrder.Header] = []
}
