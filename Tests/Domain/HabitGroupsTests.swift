import Foundation
import Testing
@testable import SuperPooper

@Suite("Habit groups")
struct HabitGroupsTests {
    private func habit(_ name: String, repeatable: Bool = false) -> TaskNote {
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
}
