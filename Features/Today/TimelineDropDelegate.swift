import SwiftUI

@MainActor
struct TimelineDropDelegate: DropDelegate {
    let drag: TaskDragState
    let moment: (CGFloat) -> Date
    let canDrop: (DayItem, TaskDragState.Source) -> Bool
    let onDrop: (DayItem, TaskDragState.Source, Date) -> Void
    let onRefused: (DayItem) -> Void

    /// A task lands here when `canDrop` says so.
    func accepts() -> Bool {
        drag.item.map { canDrop($0, drag.source) } ?? false
    }

    func dropEntered(info: DropInfo) {
        drag.turnAfterStay(.block(.timeline))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if accepts(), drag.hover(at: moment(info.location.y)) { Haptics.play(.dragStep) }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        drag.cancelTurn(.block(.timeline))
        drag.hoverMoment = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = drag.item else { return false }
        let landing = drag.hoverMoment ?? moment(info.location.y)
        let source = drag.source
        let accepted = accepts()
        drag.end()
        if accepted { onDrop(item, source, landing) } else { onRefused(item) }
        return true
    }
}
