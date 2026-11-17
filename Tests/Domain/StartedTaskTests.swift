import Foundation
import Testing
@testable import SuperPooperApp

/// A started task (TaskNotes `in-progress`) is this week's everywhere: in today, in the This week list, not promoted;
/// Start and Not started are offered by its state; its fill runs from opaque at the left edge to clear.
struct StartedTaskTests {
    private let availability = ActionAvailability(capabilities: StoreCapabilities(opensExternally: true, hasTrash: true))
    private let menu: [ActionID] = [.done, .start, .notStarted]

    private func item(_ task: TaskItem, _ state: DayItemState = .open) -> DayItem {
        DayItem(task: task, state: state, problems: [])
    }

    @Test func startedCountsAsThisWeek() {
        let started = makeTask("Report") { $0.isStarted = true }
        #expect(started.status.isThisWeek)
        #expect(!started.canPromote)
        #expect(TaskListFilter(statuses: [.thisWeek]).matches(started, rules: TestConfig.rules.day))
        #expect(!TaskListFilter(statuses: [.halfYear]).matches(started, rules: TestConfig.rules.day))
        let groups = TaskListFilter(statuses: TaskStatus.open).groups(of: [started, makeTask("Plan")], query: "", rules: TestConfig.rules.day)
        #expect(groups.map(\.status) == [.thisWeek] && groups.first?.tasks.count == 2, "in This week, with the others")
    }

    @Test func startIsOfferedToAnOpenTaskAndNotStartedToAStartedOne() {
        #expect(availability.entries(menu, for: item(makeTask("Report"))).map(\.action) == [.done, .start])
        #expect(availability.entries(menu, for: item(makeTask("Report") { $0.isStarted = true })).map(\.action) == [.done, .notStarted])
        #expect(availability.entries(menu, for: item(makeTask("Report"), .marked(.done))).map(\.action) == [.done])
        #expect(availability.entries(menu, for: item(makeHabit("Water"))).map(\.action) == [.done])
    }

    /// Whole up to the transition, nothing from its end on (D-192).
    @Test func theFillIsWholeUpToItsTransitionAndClearAfterIt() {
        let stops = StartedFill.stops(color: .blue, start: 0.2, end: 0.6)
        #expect(stops.first?.location == 0.2 && stops.last?.location == 0.6)
        #expect(StartedFill.stops(color: .blue, start: 0.5, end: 0.5).map(\.location) == [0.5, 0.5], "a sharp edge")
        #expect(TestConfig.defaults.pool.startedFillMiddle == 0.17 && TestConfig.defaults.pool.startedFillWidth == 0.33)
    }

}

/// Where a started task's mark stands and how far its name moves (`StartedLayout`).
@Suite("Started look")
struct StartedLayoutTests {
    private let size = CGSize(width: 300, height: 40)

    @Test func theCircleIsConcentricWithThePlatesCornerAndAsBigAsSet() throws {
        let sizes: ClosedRange<CGFloat> = 10...40
        let largest = StartedLayout(look: .circle, fillMiddle: 0.17, fillWidth: 0.33, titleAfterFill: false, circleSize: 1)
        // A plate 40 tall is never rounder than 20: the largest circle fills its height.
        #expect(try #require(largest.circle(plateHeight: 40, cornerRadius: 26, sizes: sizes)) == CGRect(x: 0, y: 0, width: 40, height: 40))
        let half = StartedLayout(look: .circle, fillMiddle: 0.17, fillWidth: 0.33, titleAfterFill: false, circleSize: 0.5, titleGap: 6)
        #expect(try #require(half.circle(plateHeight: 40, cornerRadius: 26, sizes: sizes)) == CGRect(x: 7.5, y: 7.5, width: 25, height: 25))
        #expect(half.titleShift(plateSize: size, cornerRadius: 26, sizes: sizes, inset: 5) == 33.5)
        // A gap far below zero brings the name back to where it stands on a task not started, no further.
        var flush = half
        flush.titleGap = -48
        #expect(flush.titleShift(plateSize: size, cornerRadius: 26, sizes: sizes, inset: 5) == 0)
    }

    /// On a taller plate the circle's lower half reaches down to the plate's bottom, with the gaps a one-line plate has.
    @Test func onATallPlateTheCircleBecomesABar() throws {
        let largest = StartedLayout(look: .circle, fillMiddle: 0.17, fillWidth: 0.33, titleAfterFill: false, circleSize: 1)
        #expect(try #require(largest.circle(plateHeight: 80, cornerRadius: 26, sizes: 10...40)) == CGRect(x: 6, y: 6, width: 40, height: 68))
        #expect(try #require(largest.circle(plateHeight: 80, cornerRadius: 26, sizes: 10...40, oneLineHeight: 40)) == CGRect(x: 0, y: 0, width: 40, height: 80))
    }

    @Test func theFillMovesTheNameOnlyWhenItGoesAfterIt() {
        let over = StartedLayout(look: .fill, fillMiddle: 0.25, fillWidth: 0.5, titleAfterFill: false)
        #expect(over.titleShift(plateSize: size, cornerRadius: 26, sizes: 10...40, inset: 5) == 0)
        #expect(over.circle(plateHeight: 40, cornerRadius: 26, sizes: 10...40) == nil)
        let after = StartedLayout(look: .fill, fillMiddle: 0.25, fillWidth: 0.5, titleAfterFill: true)
        #expect(after.titleShift(plateSize: size, cornerRadius: 26, sizes: 10...40, inset: 5) == 145)
    }

    /// The fill covers the whole plate: the color whole up to the transition, nothing past it; the transition stands
    /// around its middle, half its width on each side, and never past the plate's edges (D-192).
    @Test func theFillsTransitionStandsAroundItsMiddle() {
        let fill = StartedLayout(look: .fill, fillMiddle: 0.6, fillWidth: 0.2, titleAfterFill: true)
        #expect(abs(fill.fillStart - 0.5) < 1e-9 && abs(fill.fillEnd - 0.7) < 1e-9)
        #expect(abs(fill.titleShift(plateSize: size, cornerRadius: 26, sizes: 10...40, inset: 5) - (size.width * 0.7 - 5)) < 1e-6)
        let sharp = StartedLayout(look: .fill, fillMiddle: 0.9, fillWidth: 0.4, titleAfterFill: false)
        #expect(abs(sharp.fillStart - 0.7) < 1e-9 && sharp.fillEnd == 1, "within the plate")
        #expect(StartedLayout(look: .fill, fillMiddle: 0.3, fillWidth: 0, titleAfterFill: false).fillStart == 0.3)
    }

    @Test func byDefaultTheFillLiesUnderTheName() {
        #expect(TestConfig.defaults.pool.startedLook == .fill)
        #expect(!TestConfig.defaults.pool.startedTitleAfterFill)
    }
}
