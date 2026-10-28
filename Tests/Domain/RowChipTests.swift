import Foundation
import Testing
@testable import SuperPooperApp

/// The chips of a pool row: a task waiting for another one shows only the link chip, not a grey row; chips follow
/// the order from the settings.
struct RowChipTests {
    private func chips(_ item: DayItem, order: [String] = TestConfig.defaults.pool.chipOrder) -> [String] {
        RowChip.chips(for: item, order: RowChipKind.ordered(order), tokens: TestConfig.tokens).map(\.id)
    }

    @Test func aBlockedTaskHasTheLinkChip() {
        let task = makeTask("Hang the shelf") { $0.previousTasks = ["Find the drill"] }
        let blocked = DayItem(task: task, state: .open, blockers: [.task("Find the drill")], problems: [])
        let free = DayItem(task: task, state: .open, blockers: [], problems: [])
        #expect(chips(blocked) == ["blocked"])
        #expect(chips(free).isEmpty)
    }

    @Test func theRepeatingChipIsLastByDefaultAndTheOrderComesFromTheSettings() {
        let task = makeTask("Stretch") { $0.status = .habit; $0.isHighPriority = true; $0.feel = .pleasant }
        let item = DayItem(task: task, state: .open, blockers: [], problems: [])
        #expect(chips(item) == ["high", "feel", "habit"])
        #expect(chips(item, order: ["habit", "feel"]) == ["habit", "feel", "high"])
    }

    @Test func aNeutralTaskHasNoFeelChip() {
        let item = DayItem(task: makeTask("Read"), state: .open, blockers: [], problems: [])
        #expect(chips(item).isEmpty)
    }
}
