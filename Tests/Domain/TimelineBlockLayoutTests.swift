import Foundation
import Testing
@testable import SuperPooperApp

/// Where the blocks of a timeline column go: events at their exact times, minimum heights of tasks, short tasks stacked,
/// overlaps indented or in columns.
struct TimelineBlockLayoutTests {
    private let window = TimelineWindow(start: TestCalendar.date(TestCalendar.wednesday, "09:00"),
                                        end: TestCalendar.date(TestCalendar.wednesday, "13:00"))
    private var layout: TimelineBlockLayout {
        TimelineBlockLayout(window: window, hourHeight: 60, minimumEventHeight: 20, minimumTaskHeight: 40, titleRoomShare: 1)
    }

    private func event(_ title: String, _ start: String, _ end: String) -> TimelineSlot {
        let event = makeEvent(title, from: start, to: end)
        return TimelineSlot(content: .event(event), start: event.start, end: event.end, isPast: false)
    }

    private func task(_ name: String, _ start: String, _ end: String) -> TimelineSlot {
        TimelineSlot(content: .task(DayItem(listed: makeTask(name))), start: TestCalendar.date(TestCalendar.wednesday, start),
                     end: TestCalendar.date(TestCalendar.wednesday, end), isPast: false)
    }

    /// An event spans exactly its time, however short; a task gets at least its minimum height.
    @Test func eventsStandExactlyAtTheirTimesAndTasksGetTheirMinimumHeight() {
        let placed = layout.place([event("Standup", "10:00", "10:10"), task("Call", "11:00", "11:10"), event("Lunch", "12:00", "13:00")])
        #expect(placed.map(\.top) == [60, 120, 180])
        #expect(placed.map(\.height) == [10, 40, 60])
        #expect(placed.allSatisfy { $0.columnCount == 1 })
    }

    /// A task right after a short one is drawn below it, edge to edge, when the minimum height reaches past its start.
    @Test func aChainOfShortTasksStacksEdgeToEdge() {
        let placed = layout.place([task("First", "10:00", "10:15"), task("Second", "10:15", "10:30"), task("Third", "10:20", "10:30")])
        #expect(placed.map(\.top) == [60, 100, 140])
        #expect(placed.map(\.indent) == [0, 0, 0])
        #expect(placed.map(\.columnCount) == [1, 1, 1])
    }

    /// Short tasks overlapping in time stack too: the earlier one has no height to take the later one beside its title.
    @Test func overlappingShortTasksStack() {
        let placed = layout.place([task("First", "10:00", "10:20"), task("Second", "10:10", "10:30")])
        #expect(placed.map(\.top) == [60, 100])
        #expect(placed.map(\.columnCount) == [1, 1])
    }

    /// Events are never pushed down: one starting under a short task's title stays at its time, beside it; a short event
    /// after a short event stays at its time too.
    @Test func eventsAreNeverStacked() {
        let afterTask = layout.place([task("Call", "10:00", "10:10"), event("Standup", "10:10", "10:20")])
        #expect(afterTask.map(\.top) == [60, 70])
        #expect(afterTask.map(\.columnCount) == [2, 2])
        let afterEvent = layout.place([event("One", "10:00", "10:05"), event("Two", "10:05", "10:15")])
        #expect(afterEvent.map(\.top) == [60, 65])
        #expect(afterEvent.map(\.height) == [5, 10])
    }

    /// A task starting below an event's title lies over the event at its own time, indented; so does an event over a task.
    @Test func aLaterBlockBelowTheTitleLiesOverAnyKind() {
        let taskOverEvent = layout.place([event("Meeting", "10:00", "11:00"), task("Note", "10:30", "10:40")])
        #expect(taskOverEvent.map(\.top) == [60, 90])
        #expect(taskOverEvent.map(\.indent) == [0, 1])
        let eventOverTask = layout.place([task("Write", "10:00", "11:30"), event("Call", "10:45", "11:00")])
        #expect(eventOverTask.map(\.top) == [60, 105])
        #expect(eventOverTask.map(\.indent) == [0, 1])
    }

    /// Blocks starting together share the width, the longer of the two on the left; a later one that leaves the earlier
    /// title readable lies over the long one, one indent step in, across the rest of the width.
    @Test func overlapsStartingTogetherShareTheWidthAndALaterOneLiesOverIndented() {
        let placed = layout.place([event("Short", "10:00", "10:30"), event("Long", "10:00", "11:30"), event("Later", "10:45", "11:00")])
        #expect(placed.map(\.slot.id) == ["event:" + makeEvent("Long", from: "10:00", to: "11:30").id,
                                          "event:" + makeEvent("Short", from: "10:00", to: "10:30").id,
                                          "event:" + makeEvent("Later", from: "10:45", to: "11:00").id])
        #expect(placed.map(\.indent) == [0, 0, 1])
        #expect(placed.map(\.column) == [0, 1, 0])
        #expect(placed.map(\.columnCount) == [2, 2, 1])
        let short = placed[1].horizontal(in: 300, indentStep: 10)
        #expect(short.x == 150 && short.width == 150)
        let later = placed[2].horizontal(in: 300, indentStep: 10)
        #expect(later.x == 10 && later.width == 290)
    }

    /// Three blocks, each starting under the title of the one before, step in one more each time.
    @Test func eachLaterOverlapStepsInOneMore() {
        let placed = layout.place([event("A", "10:00", "12:00"), event("B", "10:30", "12:00"), event("C", "11:00", "12:00"),
                                   event("D", "11:30", "12:00")])
        #expect(placed.map(\.indent) == [0, 1, 2, 3])
        #expect(placed.allSatisfy { $0.columnCount == 1 })
        #expect(placed[3].horizontal(in: 300, indentStep: 10).x == 30)
    }

    /// A block starting inside the earlier one's title room would hide its title: it stands beside it instead. The room is
    /// the earlier block's minimum height (a task's is taller than an event's).
    @Test func aBlockStartingInsideTheEarlierTitleStandsBesideIt() {
        let events = layout.place([event("Long", "10:00", "11:00"), event("Close", "10:25", "10:45")])
        #expect(events.map(\.indent) == [0, 1], "25 points under an event clear its 20-point title")
        let tasks = layout.place([task("Long", "10:00", "11:00"), task("Close", "10:25", "10:45")])
        #expect(tasks.map(\.indent) == [0, 0])
        #expect(tasks.map(\.column) == [0, 1])
        #expect(tasks.map(\.columnCount) == [2, 2])
    }

    /// Outside the window a block is left out; one reaching into it starts at the window's top.
    @Test func theWindowCutsTheBlocks() {
        let placed = layout.place([event("Early", "07:00", "08:00"), event("Into", "08:30", "10:00"), event("Late", "13:00", "14:00")])
        #expect(placed.count == 1)
        #expect(placed.first?.top == 0)
        #expect(placed.first?.height == 60)
    }
}
