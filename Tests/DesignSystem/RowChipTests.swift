import Foundation
import Testing
@testable import SuperPooperApp

/// The chips of a pool row: a task waiting for another one shows only the link chip, not a grey row; chips follow
/// the order from the settings.
struct RowChipTests {
    private func chips(_ item: DayItem, order: [String] = TestConfig.defaults.pool.chipOrder) -> [String] {
        RowChip.chips(for: item, order: RowChipKind.ordered(order)).map(\.id)
    }
    /// One table of looks: a property has the same icon and color in a row's chips, the chip order and the review.
    @Test func aPropertyLooksTheSameEverywhere() {
        #expect(ChipLook.pleasant.tint == .heart)
        #expect(ChipLook.needEnergy.tint == .energy)
        #expect(ChipLook.pleasant.icon == .pleasant)
        #expect(ToggleChip(.pleasant, isOn: true) {}.tint == .heart)
    }


    /// High priority is no chip at the end of the row: the look chosen in the settings marks it (.25226).
    @Test func highPriorityHasNoChip() {
        let item = DayItem(task: makeTask("Call the bank") { $0.isHighPriority = true }, state: .open, problems: [])
        #expect(chips(item, order: ["high", "feel"]).isEmpty)
        #expect(!TestConfig.defaults.pool.chipOrder.contains("high"))
    }

    /// The page peek measures the rows' last chip by its kind's icon: the same icon the row draws; the chip order in
    /// the settings shows every look a kind can have.
    @MainActor @Test func aChipKindNamesTheIconItsChipShows() {
        let task = makeTask("Stretch") { $0.status = .habit; $0.isHighPriority = true; $0.feel = .needEnergy }
        let item = DayItem(task: task, state: .open, problems: [.recurrenceWithoutStart])
        for chip in RowChip.chips(for: item, order: RowChipKind.allCases) {
            #expect(chip.look.icon == chip.kind.icon)
            #expect(chip.kind.looks.contains(chip.look))
        }
        let pleasant = DayItem(task: makeTask("Bake") { $0.feel = .pleasant }, state: .open, problems: [])
        #expect(RowChip.chips(for: pleasant, order: [.feel]).map(\.look) == [.pleasant])
        let icons = TestConfig.decode(IconSet.self, "icons.json")
        #expect(Chip.width(of: .habit, tokens: TestConfig.tokens, icons: icons, scale: 3) > TestConfig.tokens.space(.chipHorizontal) * 2)
    }

}
