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
}
