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

/// How a started task's fill stands and how far its name moves (`StartedLayout`).
@Suite("Started look")
struct StartedLayoutTests {
    /// The name stands `titleGap` past the transition's end; far below zero it is back where it stands on a task not
    /// started, no further (D-193).
    @Test func theNameStandsTheGapPastTheFill() {
        let fill = StartedLayout(fillMiddle: 0.25, fillWidth: 0.5, titleGap: 6)
        #expect(fill.titleShift(plateWidth: 300, inset: 5) == 151)
        var over = fill
        over.titleGap = -400
        #expect(over.titleShift(plateWidth: 300, inset: 5) == 0)
    }

    /// The fill covers the whole plate: the color whole up to the transition, nothing past it; the transition stands
    /// around its middle, half its width on each side, and never past the plate's edges (D-192).
    @Test func theFillsTransitionStandsAroundItsMiddle() {
        let fill = StartedLayout(fillMiddle: 0.6, fillWidth: 0.2)
        #expect(abs(fill.fillStart - 0.5) < 1e-9 && abs(fill.fillEnd - 0.7) < 1e-9)
        let sharp = StartedLayout(fillMiddle: 0.9, fillWidth: 0.4)
        #expect(abs(sharp.fillStart - 0.7) < 1e-9 && sharp.fillEnd == 1, "within the plate")
        #expect(StartedLayout(fillMiddle: 0.3, fillWidth: 0).fillStart == 0.3)
    }

    @Test func theGapCanBringTheNameBackOverAnyFill() {
        #expect(TestConfig.rules.limits.startedTitleGap.min <= -400)
    }
}
