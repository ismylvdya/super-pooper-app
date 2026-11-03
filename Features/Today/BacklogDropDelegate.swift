import SwiftUI

/// Dropping on a backlog page: the task takes that list's level (Soon from today's pool is Not today). Over the page the
/// task shows there, faint, where the list would hold it.
@MainActor
struct BacklogDropDelegate: DropDelegate {
    let drag: TaskDragState
    let list: String
    let animation: Animation
    let canDrop: (DayItem) -> Bool
    let onDrop: (DayItem, TaskDragState.Source) -> Void

    func validateDrop(info: DropInfo) -> Bool { validate() }

    /// Only a task from elsewhere lands here: a pool section's header or a worm dragged whole never does.
    func validate() -> Bool {
        guard let item = drag.item, drag.source != .backlog(list), drag.source.wormMembers.isEmpty else { return false }
        return canDrop(item)
    }

    func dropEntered(info: DropInfo) {
        drag.turn(.backlog(list))
        withAnimation(animation) { drag.backlogTarget = list }
        Haptics.play(.dragStep)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        withAnimation(animation) { if drag.backlogTarget == list { drag.backlogTarget = nil } }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = drag.item else { return false }
        let source = drag.source
        drag.end()
        onDrop(item, source)
        return true
    }
}
