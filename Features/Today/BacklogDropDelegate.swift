import SwiftUI

/// Dropping on a backlog page: the task takes that list's level (Soon from today's pool is Not today). Over the page the
/// rows part where the list would hold it, and a row of the page dragged within it takes a new place in the list. What cannot land here shows no sign while it is held; let go, it is refused
/// with a banner (`onRefused`).
@MainActor
struct BacklogDropDelegate: DropDelegate {
    let drag: TaskDragState
    let list: String
    let animation: Animation
    let canDrop: (DayItem) -> Bool
    let onDrop: (DayItem, TaskDragState.Source) -> Void
    let onRefused: (DayItem) -> Void
    /// The page's rows as they stood when the finger came, for a task dragged within the page.
    let rows: () -> [PoolDropOrder.Row]
    let onReorder: ([String]) -> Void

    /// Only a task from elsewhere lands here: a pool section's header or a worm dragged whole never does.
    func accepts() -> Bool {
        guard let item = drag.item, drag.source != .backlog(list), drag.source.wormMembers.isEmpty else { return false }
        return canDrop(item)
    }

    func dropEntered(info: DropInfo) {
        drag.turnAfterStay(.backlog(list))
        // A row of this page dragged within it closes up here too, and so does one that may not land: nothing to part for.
        if accepts() || drag.source == .backlog(list) {
            withAnimation(animation) { drag.backlogTarget = list }
            Haptics.play(.dragStep)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if drag.source == .backlog(list), let dragged = drag.item?.id {
            let order = PoolDropOrder.drop(rows: rows(), headers: [], dragged: dragged, at: info.location.y).order
            if order != drag.backlogOrder {
                withAnimation(animation) { drag.backlogOrder = order }
                Haptics.play(.dragStep)
            }
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        drag.cancelTurn(.backlog(list))
        withAnimation(animation) {
            if drag.backlogTarget == list { drag.backlogTarget = nil }
            drag.backlogOrder = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = drag.item else { return false }
        let source = drag.source
        let accepted = accepts()
        let isOwnRow = source == .backlog(list)
        let order = drag.backlogOrder
        drag.end()
        if isOwnRow, let order { onReorder(order) }
        if accepted { onDrop(item, source) } else if !isOwnRow { onRefused(item) }
        return true
    }
}
