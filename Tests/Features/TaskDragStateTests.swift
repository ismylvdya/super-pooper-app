import Testing
@testable import SuperPooperApp

/// A drag asks the Today pages to turn; the screen turns by the layout it shows at that moment and clears the request,
/// so the same block can be asked for again later in the drag.
@MainActor
struct TaskDragStateTests {
    @Test func aTurnIsARequestTheScreenClears() {
        let drag = TaskDragState()
        #expect(drag.turnRequest == nil)
        drag.turn(.timeline)
        #expect(drag.turnRequest == .timeline)
        drag.turnHandled()
        #expect(drag.turnRequest == nil)
        drag.turn(.timeline)
        #expect(drag.turnRequest == .timeline)
    }

    /// Over the pool the dragged task's row is an empty gap the other rows part around (.21800): from the pool or from
    /// the timeline; away from the pool, and after the drop, it is a row again.
    @Test func overThePoolTheDraggedRowIsAGap() {
        let drag = TaskDragState()
        let task = DayItem(listed: makeTask("Pay the internet"))
        _ = drag.begin(task, from: .pool)
        #expect(!drag.isGap(task.id), "lifted, not yet over the pool")
        drag.poolOrder = ["Call the bank", task.id]
        #expect(drag.isGap(task.id))
        #expect(!drag.isGap("Call the bank"))
        drag.poolOrder = nil
        #expect(!drag.isGap(task.id), "the finger left the pool")
        _ = drag.begin(task, from: .timeline(slot: nil))
        drag.poolOrder = [task.id]
        #expect(drag.isGap(task.id))
        drag.end()
        #expect(!drag.isGap(task.id))
    }
}
