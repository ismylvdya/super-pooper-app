import Foundation
import Testing
@testable import SuperPooperApp

/// Where the blocks of a timeline column go: minimum heights, chains pushed down, overlaps in columns.
struct TimelineBlockLayoutTests {
    private let window = TimelineWindow(start: TestCalendar.date(TestCalendar.wednesday, "09:00"),
                                        end: TestCalendar.date(TestCalendar.wednesday, "13:00"))
    private var layout: TimelineBlockLayout {
        TimelineBlockLayout(window: window, hourHeight: 60, minimumEventHeight: 20, minimumTaskHeight: 40)
    }

    private func event(_ title: String, _ start: String, _ end: String) -> TimelineSlot {
        let event = makeEvent(title, from: start, to: end)
        return TimelineSlot(content: .event(event), start: event.start, end: event.end, isPast: false)
    }

    private func task(_ name: String, _ start: String, _ end: String) -> TimelineSlot {
        TimelineSlot(content: .task(DayItem(listed: makeTask(name))), start: TestCalendar.date(TestCalendar.wednesday, start),
                     end: TestCalendar.date(TestCalendar.wednesday, end), isPast: false)
    }

    @Test func blocksStandAtTheirTimeWithAtLeastTheirMinimumHeight() {
        let placed = layout.place([event("Standup", "10:00", "10:10"), task("Call", "11:00", "11:10"), event("Lunch", "12:00", "13:00")])
        #expect(placed.map(\.top) == [60, 120, 180])
        #expect(placed.map(\.height) == [20, 40, 60])
        #expect(placed.allSatisfy { $0.columnCount == 1 })
    }

    /// A task right after a short one is drawn below it, not over it, when the minimum height reaches past its start.
    @Test func aChainIsPushedDownInsteadOfOverlapping() {
        let placed = layout.place([task("First", "10:00", "10:15"), task("Second", "10:15", "10:30")])
        #expect(placed.map(\.top) == [60, 100])
        #expect(placed.map(\.columnCount) == [1, 1])
    }

    /// Blocks that overlap in time share the width, the longer of two starting together on the left.
    @Test func overlapsShareTheWidthInColumns() {
        let placed = layout.place([event("Short", "10:00", "10:30"), event("Long", "10:00", "11:30"), event("Later", "10:45", "11:00")])
        #expect(placed.map(\.slot.id) == ["event:" + makeEvent("Long", from: "10:00", to: "11:30").id,
                                          "event:" + makeEvent("Short", from: "10:00", to: "10:30").id,
                                          "event:" + makeEvent("Later", from: "10:45", to: "11:00").id])
        #expect(placed.map(\.column) == [0, 1, 1])
        #expect(placed.allSatisfy { $0.columnCount == 2 })
        let short = placed[1].horizontal(in: 300)
        #expect(short.x == 150 && short.width == 150)
    }

    /// Outside the window a block is left out; one reaching into it starts at the window's top.
    @Test func theWindowCutsTheBlocks() {
        let placed = layout.place([event("Early", "07:00", "08:00"), event("Into", "08:30", "10:00"), event("Late", "13:00", "14:00")])
        #expect(placed.count == 1)
        #expect(placed.first?.top == 0)
        #expect(placed.first?.height == 60)
    }
}
