import Foundation
import Testing
@testable import SuperPooperApp

@Suite("Habit groups")
struct HabitGroupsTests {
    private func habit(_ name: String, repeatable: Bool = false) -> TaskItem {
        makeHabit(name) { $0.habit.repeatable = repeatable }
    }

    @Test func repeatableTasksStandApartInTheirOrder() {
        let groups = HabitGroups([habit("Run"), habit("Bills", repeatable: true), habit("Read"), habit("Laundry", repeatable: true)])
        #expect(groups.tracked.map(\.name) == ["Run", "Read"])
        #expect(groups.repeatable.map(\.name) == ["Bills", "Laundry"])
    }

    @Test func movingInsideAGroupKeepsTheOtherGroup() {
        let groups = HabitGroups([habit("Run"), habit("Bills", repeatable: true), habit("Read"), habit("Laundry", repeatable: true)])
        #expect(groups.order(moving: [1], to: 0, inRepeatable: false) == ["Read", "Run", "Bills", "Laundry"])
        #expect(groups.order(moving: [0], to: 2, inRepeatable: true) == ["Run", "Read", "Laundry", "Bills"])
    }

    /// A habit's repeatable subtask shows on its parent's page, not as a row; a search for it alone finds no row either.
    @Test func repeatableSubtasksAreNotHabitRows() {
        let pushUps = makeHabit("Push-ups", status: .habit) { $0.projects = ["Run"]; $0.habit.repeatable = true }
        let all = [habit("Run"), pushUps, habit("Bills", repeatable: true)]
        let groups = HabitGroups(all)
        #expect(groups.tracked.map(\.name) == ["Run"])
        #expect(groups.repeatable.map(\.name) == ["Bills"])
        #expect(HabitGroups([pushUps], active: all).repeatable.isEmpty)
    }
}
