import Foundation
import Testing
@testable import SuperPooperApp

/// Chain placement, overlapping blocks and the visible timeline windows.
@Suite("Timeline layout")
struct TimelineLayoutTests {
    private let call = makeEvent("Call with dad", from: "19:00", to: "20:00")
    private let now = TestCalendar.date(TestCalendar.wednesday, "13:25")

    // MARK: - ChainLayout

    @Test func aBeforeChainIsPlacedBackToBackFromNow() {
        let slots = layout(.before(TimelineChain.Target(event: call)), [open("A", 15), open("B", 60), open("C", nil)])
        #expect(slots.map(\.label) == ["A 13:25–13:40", "B 13:40–14:40", "C 14:40–14:55"])
        #expect(slots.allSatisfy { !$0.isPast })
    }

    @Test func anAfterChainStartsAtTheEventEndOrAtNowWhenTheEventIsOver() {
        #expect(layout(.after(TimelineChain.Target(event: call)), [open("A", 15)]).map(\.label) == ["A 20:00–20:15"])
        let late = TestCalendar.date(TestCalendar.wednesday, "20:40")
        #expect(layout(.after(TimelineChain.Target(event: call)), [open("A", 15)], now: late).map(\.label) == ["A 20:40–20:55"])
    }

    @Test func doneItemsLeaveTheChain() {
        let slots = layout(.before(TimelineChain.Target(event: call)), [done("Done 1", 15), done("Done 2", 30), open("Open", 15)])
        #expect(slots.map(\.label) == ["Open 13:25–13:40"])
    }

    // MARK: - CascadeAssigner

    @Test func separateBlocksTakeTheFullWidth() {
        #expect(cascade([(0, 10), (10, 20), (30, 40)]) == [[0, 0, 1], [0, 0, 1], [0, 0, 1]])
    }

    /// Indent, column, column count: B starts past A's title and lies over it; C starts within B's title and stands
    /// beside it, both one step in.
    @Test func overlapsLieOverIndentedOrStandBesideWithinATitle() {
        #expect(cascade([(0, 60), (20, 60), (25, 50)]) == [[0, 0, 1], [1, 0, 2], [1, 1, 2]])
    }

    /// Past the earlier blocks' bottoms nothing is covered: back at the left edge.
    @Test func afterTheOverlapEndsTheIndentStartsOver() {
        #expect(cascade([(0, 60), (20, 60), (70, 90)]) == [[0, 0, 1], [1, 0, 1], [0, 0, 1]])
    }

    @Test func noBlocksNoPlacements() {
        #expect(CascadeAssigner.assign([]).isEmpty)
    }

    // MARK: - TimelineWindow

    @Test func theRollingWindowIsWidenedToWholeHours() {
        let window = TimelineWindow.rolling(now: now, hoursBefore: 2, hoursAfter: 10, calendar: TestCalendar.calendar)
        #expect(window.start == TestCalendar.date("2026-10-21", "11:00"))
        #expect(window.end == TestCalendar.date("2026-10-22", "00:00"))
        #expect(window.contains(now))
        #expect(!window.contains(TestCalendar.date("2026-10-21", "10:59")))
    }

    @Test func fixedHalvesAreTodaysAndAnEndBeforeTheStartMeansAfterMidnight() {
        let context = TestCalendar.context(TestCalendar.wednesday, "13:25")
        let first = TimelineWindow.fixed(start: LocalTime("06:00"), end: LocalTime("14:00"), context: context)
        let night = TimelineWindow.fixed(start: LocalTime("22:00"), end: LocalTime("02:00"), context: context)
        #expect((first.start, first.end) == (TestCalendar.date("2026-10-21", "06:00"), TestCalendar.date("2026-10-21", "14:00")))
        #expect(first.duration == 8 * 3600)
        #expect((night.start, night.end) == (TestCalendar.date("2026-10-21", "22:00"), TestCalendar.date("2026-10-22", "02:00")))
    }

    @Test func afterMidnightBeforeTheDayBoundaryTheHalvesStillShowYesterday() {
        let context = TestCalendar.context("2026-10-22", "01:30")
        let second = TimelineWindow.fixed(start: LocalTime("14:00"), end: LocalTime("22:00"), context: context)
        #expect(second.start == TestCalendar.date("2026-10-21", "14:00"))
    }

    // MARK: - Helpers

    private func open(_ name: String, _ minutes: Int?) -> DayItem {
        DayItem(task: makeTask(name) { $0.timeEstimate = minutes }, state: .open, blockers: [], problems: [])
    }

    private func done(_ name: String, _ minutes: Int?) -> DayItem {
        DayItem(task: makeTask(name) { $0.timeEstimate = minutes }, state: .marked(.done), blockers: [], problems: [])
    }

    private func layout(_ anchor: TimelineChain.Anchor, _ items: [DayItem], now: Date? = nil) -> [TimelineSlot] {
        ChainLayout(rules: TestConfig.rules.day).entries(for: TimelineChain(anchor: anchor, items: items), now: now ?? self.now)
    }

    /// Blocks with a title room of 10 points: [indent, column, column count] each.
    private func cascade(_ blocks: [(Double, Double)]) -> [[Int]] {
        CascadeAssigner.assign(blocks.map { CascadeAssigner.Block(top: $0.0, bottom: $0.1, titleRoom: 10) })
            .map { [$0.indent, $0.column, $0.columnCount] }
    }
}

private extension TimelineSlot {
    var label: String {
        guard case .task(let item) = content else { return "?" }
        return "\(item.id) \(clockTime(start))–\(clockTime(end))"
    }
}
