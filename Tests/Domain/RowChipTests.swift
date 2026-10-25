import Foundation
import Testing
@testable import SuperPooper

/// The chips of a pool row: a task waiting for another one shows only the link chip, not a grey row.
struct RowChipTests {
    private func chips(_ item: DayItem) -> [String] {
        RowChip.chips(for: item, today: LocalDate(TestCalendar.wednesday), rules: TestConfig.rules, tokens: TestConfig.tokens).map(\.id)
    }

    @Test func aBlockedTaskHasTheLinkChip() {
        let task = makeTask("Hang the shelf") { $0.previousTasks = ["Find the drill"] }
        let blocked = DayItem(task: task, state: .open, blockers: [.task("Find the drill")], problems: [])
        let free = DayItem(task: task, state: .open, blockers: [], problems: [])
        #expect(chips(blocked) == ["blocked"])
        #expect(chips(free).isEmpty)
    }
}
