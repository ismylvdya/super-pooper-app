import Testing
@testable import SuperPooperApp

/// A drag asks the Today pages to turn; the screen turns by the layout it shows at that moment and clears the request,
/// so the same block can be asked for again later in the drag.
@MainActor
struct TaskDragStateTests {
    @Test func aTurnIsARequestTheScreenClears() {
        let drag = TaskDragState()
        #expect(drag.turnRequest == nil)
        drag.turn(.block(.timeline))
        #expect(drag.turnRequest == .block(.timeline))
        drag.turnHandled()
        #expect(drag.turnRequest == nil)
        drag.turn(.block(.timeline))
        #expect(drag.turnRequest == .block(.timeline))
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

    /// A drag over a page's edge asks for that page, a backlog page too.
    @Test func aDragOverAPageEdgeAsksForThatPage() {
        let drag = TaskDragState()
        drag.turn(.backlog("thisWeek"))
        #expect(drag.turnRequest == .backlog("thisWeek"))
    }

    /// Over a backlog page the dragged task is listed there faintly; a row of that page itself is not listed twice, and
    /// after the drop nothing is faint any more.
    @Test func overABacklogPageTheTaskShowsFaintlyThere() {
        let drag = TaskDragState()
        let task = DayItem(listed: makeTask("Pay the internet"))
        _ = drag.begin(task, from: .pool)
        #expect(!drag.isBacklogGhost(task.id, on: "someday"))
        drag.backlogTarget = "someday"
        #expect(drag.isBacklogGhost(task.id, on: "someday"))
        #expect(!drag.isBacklogGhost(task.id, on: "thisWeek"))
        _ = drag.begin(task, from: .backlog("someday"))
        drag.backlogTarget = "someday"
        #expect(!drag.isBacklogGhost(task.id, on: "someday"), "already one of its rows")
        drag.end()
        #expect(drag.backlogTarget == nil)
    }

    /// The tab bar's "+" dragged over the pool is no note: its room there is a gap of its own the rows part around.
    @Test func aNewItemDragHasNoNoteButAGapInThePool() {
        let drag = TaskDragState()
        _ = drag.beginNewItem()
        #expect(drag.item == nil && drag.source == .newItem)
        #expect(drag.draggedID == TaskDragState.newItemGap && drag.isDragging)
        #expect(!drag.isGap(TaskDragState.newItemGap), "lifted, not yet over the pool")
        #expect(drag.hover(poolOrder: ["A", TaskDragState.newItemGap, "B"]))
        #expect(drag.isGap(TaskDragState.newItemGap))
        #expect(!drag.isGap("A"))
    }

    @Test func endingANewItemDragClearsIt() {
        let drag = TaskDragState()
        _ = drag.beginNewItem()
        _ = drag.hover(poolOrder: [TaskDragState.newItemGap])
        drag.end()
        #expect(drag.source == .pool && drag.draggedID == nil && !drag.isDragging)
        #expect(!drag.isGap(TaskDragState.newItemGap))
        let task = DayItem(listed: makeTask("Pay the internet"))
        _ = drag.beginNewItem()
        _ = drag.begin(task, from: .pool)
        #expect(drag.draggedID == task.id, "a task picked up after it is the task")
    }

    /// Let go outside every drop target there is no drop to end the drag: the lifted finger ends it, so the day swipe
    /// (blocked while a task is dragged) works again.
    @Test func aDragLetGoOutsideEveryTargetEnds() async {
        let drag = TaskDragState()
        _ = drag.begin(DayItem(listed: makeTask("Pay the internet")), from: .pool)
        await drag.fingerLifted(settling: 1, delay: NoDelay())
        #expect(drag.item == nil && !drag.isDragging)
        _ = drag.beginNewItem()
        await drag.fingerLifted(settling: 1, delay: NoDelay())
        #expect(!drag.isDragging)
        _ = drag.beginSection("day")
        await drag.fingerLifted(settling: 1, delay: NoDelay())
        #expect(drag.source == .pool)
    }

    /// A finger lifted from one drag does not end the next one begun while it settled.
    @Test func aLiftedFingerLeavesTheNextDragAlone() async {
        let drag = TaskDragState()
        let gate = GatedDelay()
        _ = drag.begin(DayItem(listed: makeTask("Pay the internet")), from: .pool)
        let lifted = Task { await drag.fingerLifted(settling: 1, delay: gate) }
        await gate.gate.arrived()
        _ = drag.begin(DayItem(listed: makeTask("Call the bank")), from: .timeline(slot: nil))
        await gate.gate.open()
        await lifted.value
        #expect(drag.item?.id == "Call the bank")
    }
}
