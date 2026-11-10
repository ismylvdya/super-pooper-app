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

    @Test func theFillIsOpaqueAtTheLeftEdgeAndClearAtItsEnd() {
        let stops = StartedFill.stops(color: .blue)
        #expect(stops.first?.location == 0 && stops.last?.location == 1)
        #expect(TestConfig.defaults.pool.startedFillLength == 0.33)
    }

}

/// Where a started task's mark stands and how far its name moves (`StartedLayout`).
@Suite("Started look")
struct StartedLayoutTests {
    private let size = CGSize(width: 300, height: 40)

    @Test func theCircleIsConcentricWithThePlatesCornerAndAsBigAsSet() throws {
        let sizes: ClosedRange<CGFloat> = 10...40
        let largest = StartedLayout(look: .circle, fillLength: 0.33, titleAfterFill: false, circleSize: 1)
        // A plate 40 tall is never rounder than 20: the largest circle fills its height.
        #expect(try #require(largest.circle(plateHeight: 40, cornerRadius: 26, sizes: sizes)) == CGRect(x: 0, y: 0, width: 40, height: 40))
        let half = StartedLayout(look: .circle, fillLength: 0.33, titleAfterFill: false, circleSize: 0.5)
        #expect(try #require(half.circle(plateHeight: 40, cornerRadius: 26, sizes: sizes)) == CGRect(x: 7.5, y: 7.5, width: 25, height: 25))
        #expect(half.titleShift(plateSize: size, cornerRadius: 26, sizes: sizes, inset: 5, gap: 6) == 33.5)
    }

    @Test func theFillMovesTheNameOnlyWhenItGoesAfterIt() {
        let over = StartedLayout(look: .fill, fillLength: 0.5, titleAfterFill: false)
        #expect(over.titleShift(plateSize: size, cornerRadius: 26, sizes: 10...40, inset: 5, gap: 6) == 0)
        #expect(over.circle(plateHeight: 40, cornerRadius: 26, sizes: 10...40) == nil)
        let after = StartedLayout(look: .fill, fillLength: 0.5, titleAfterFill: true)
        #expect(after.titleShift(plateSize: size, cornerRadius: 26, sizes: 10...40, inset: 5, gap: 6) == 145)
    }

    @Test func byDefaultTheFillLiesUnderTheName() {
        #expect(TestConfig.defaults.pool.startedLook == .fill)
        #expect(!TestConfig.defaults.pool.startedTitleAfterFill)
    }
}
