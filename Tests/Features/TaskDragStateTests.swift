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

    /// Each new landing spot on the timeline and each row passed in the pool is a step the finger feels (.4): the same
    /// spot or order again is not.
    @Test func aNewSpotOrPoolOrderIsAStepAndTheSameOneIsNot() {
        let drag = TaskDragState()
        let task = DayItem(listed: makeTask("Pay the internet"))
        _ = drag.begin(task, from: .pool)
        let ten = TestCalendar.date(TestCalendar.wednesday, "10:00")
        #expect(drag.hover(at: ten))
        #expect(!drag.hover(at: ten))
        #expect(drag.hover(at: ten.addingTimeInterval(5 * 60)))
        #expect(drag.hoverMoment == ten.addingTimeInterval(5 * 60))
        #expect(drag.hover(poolOrder: [task.id, "Call the bank"]))
        #expect(!drag.hover(poolOrder: [task.id, "Call the bank"]))
        #expect(drag.hover(poolOrder: ["Call the bank", task.id]))
    }

    /// The faint copy on the timeline stands where the task would land, as long as its block would be (.3).
    @Test func theLandingCopyStandsAtTheSpotForTheTasksEstimate() {
        let task = DayItem(listed: makeTask("Pay the internet") { $0.timeEstimate = 45 })
        let ten = TestCalendar.date(TestCalendar.wednesday, "10:00")
        let landing = TimelineSlot.landing(task, at: ten, rules: TestConfig.rules.day)
        #expect(landing.start == ten)
        #expect(landing.end == ten.addingTimeInterval(45 * 60))
        #expect(landing.content == .task(task))
        #expect(landing.time == nil, "a copy, never picked up itself")
    }
}

