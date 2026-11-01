import Foundation
import Testing
@testable import SuperPooperApp

/// The chips of a pool row: a task waiting for another one shows only the link chip, not a grey row; chips follow
/// the order from the settings.
struct RowChipTests {
    private func chips(_ item: DayItem, order: [String] = TestConfig.defaults.pool.chipOrder) -> [String] {
        RowChip.chips(for: item, order: RowChipKind.ordered(order)).map(\.id)
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

    /// The page peek measures the rows' last chip by its kind's icon: the same icon the row draws; the chip order in
    /// the settings shows every look a kind can have.
    @Test func aChipKindNamesTheIconItsChipShows() {
        let task = makeTask("Stretch") { $0.status = .habit; $0.isHighPriority = true; $0.feel = .needEnergy }
        let item = DayItem(task: task, state: .open, blockers: [.task("Warm up")], problems: [.dependencyCycle])
        for chip in RowChip.chips(for: item, order: RowChipKind.allCases) {
            #expect(chip.look.icon == chip.kind.icon)
            #expect(chip.kind.looks.contains(chip.look))
        }
        let pleasant = DayItem(task: makeTask("Bake") { $0.feel = .pleasant }, state: .open, blockers: [], problems: [])
        #expect(RowChip.chips(for: pleasant, order: [.feel]).map(\.look) == [.pleasant])
        let icons = TestConfig.decode(IconSet.self, "icons.json")
        #expect(Chip.width(of: .habit, tokens: TestConfig.tokens, icons: icons) > TestConfig.tokens.space(.chipHorizontal) * 2)
    }

    /// One table of looks: a property has the same icon and color in a row's chips, the chip order and the review.
    @Test func aPropertyLooksTheSameEverywhere() {
        #expect(ChipLook.pleasant.tint == .heart)
        #expect(ChipLook.needEnergy.tint == .energy)
        #expect(ChipLook.blocked.tint == nil)
        #expect(ChipLook.pleasant.icon == .pleasant)
        #expect(ToggleChip(.pleasant, isOn: true) {}.tint == .heart)
        #expect(ToggleChip(.blocked, isOn: true) {}.tint == .secondaryText)
    }

    @Test func aNeutralTaskHasNoFeelChip() {
        let item = DayItem(task: makeTask("Read"), state: .open, blockers: [], problems: [])
        #expect(chips(item).isEmpty)
    }
}
