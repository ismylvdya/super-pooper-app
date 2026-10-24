import SwiftUI
import UniformTypeIdentifiers

/// The task being dragged on Today, shared by the pool, the timeline and the pages: where it came from,
/// where it would land on the timeline and the pool order while it is over the pool.
@MainActor
@Observable
final class TaskDragState {
    enum Source { case pool, timeline }

    static let types: [UTType] = [.text]

    private(set) var item: DayItem?
    private(set) var source: Source = .pool
    /// The spot on the timeline under the finger (shown next to the hours).
    var hoverMoment: Date?
    /// The pool with the task at the spot under the finger.
    var poolOrder: [String]?
    /// Turns the Today pages to a block ("pool", "timeline"); set by the screen, nothing without pages.
    var turn: (String) -> Void = { _ in }

    func begin(_ item: DayItem, from source: Source) -> NSItemProvider {
        self.item = item
        self.source = source
        hoverMoment = nil
        poolOrder = nil
        return NSItemProvider(object: item.id as NSString)
    }

    func end() {
        item = nil
        hoverMoment = nil
        poolOrder = nil
    }
}

extension View {
    /// Lets the row be picked up (long press, then move); the long-press menu still opens without moving.
    @ViewBuilder func taskDragSource(_ item: DayItem, from source: TaskDragState.Source, drag: TaskDragState?, isOn: Bool) -> some View {
        if let drag, isOn {
            onDrag { drag.begin(item, from: source) }
        } else {
            self
        }
    }
}

/// Dropping on the timeline: the task gets the time under the finger (habits cannot be dropped here).
@MainActor
struct TimelineDropDelegate: DropDelegate {
    let drag: TaskDragState
    let moment: (CGFloat) -> Date
    let onDrop: (DayItem, Date) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        drag.item.map { TaskScheduling.canMove($0.task) } ?? false
    }

    func dropEntered(info: DropInfo) {
        drag.turn("timeline")
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        drag.hoverMoment = moment(info.location.y)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        drag.hoverMoment = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = drag.item else { return false }
        let landing = drag.hoverMoment ?? moment(info.location.y)
        drag.end()
        onDrop(item, landing)
        return true
    }
}

/// Dropping on the pool: rows make room under the finger; a task from the timeline loses its time.
@MainActor
struct PoolDropDelegate: DropDelegate {
    let drag: TaskDragState
    let animation: Animation
    let rows: () -> [PoolDropOrder.Row]
    let onDrop: (DayItem, TaskDragState.Source, [String]) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        guard let item = drag.item else { return false }
        return drag.source == .pool || TaskScheduling.canMove(item.task)
    }

    func dropEntered(info: DropInfo) {
        drag.turn("pool")
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let item = drag.item else { return nil }
        let order = PoolDropOrder.order(rows: rows(), dragged: item.id, at: info.location.y)
        if order != drag.poolOrder { withAnimation(animation) { drag.poolOrder = order } }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        withAnimation(animation) { drag.poolOrder = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = drag.item else { return false }
        let order = drag.poolOrder ?? PoolDropOrder.order(rows: rows(), dragged: item.id, at: info.location.y)
        let source = drag.source
        drag.end()
        onDrop(item, source, order)
        return true
    }
}
