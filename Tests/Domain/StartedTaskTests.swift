import Foundation
import Testing
@testable import SuperPooperApp

/// A started task (TaskNotes `in-progress`) is this week's everywhere: in today, in the This week list, not promoted;
/// Start and Not started are offered according to the task’s state.
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
}
