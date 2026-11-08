import Foundation
import Testing
@testable import SuperPooperApp

/// A "+" over the pool: beside the row above its gap, or that row's subtask on the right part of the pool.
@Suite("New item nesting")
struct NewItemNestingTests {
    private let gap = NewItemPlacement.gap

    private func item(_ name: String, depth: Int = 0, habit: Bool = false) -> DayItem {
        var item = DayItem(task: habit ? makeHabit(name) : makeTask(name), state: .open, problems: [])
        item.depth = depth
        return item
    }

    private var pool: [DayItem] { [item("Trip"), item("Pack", depth: 1), item("Book", depth: 1), item("Read"), item("Run", habit: true)] }

    @Test func onTheLeftItStandsBesideTheRowAbove() {
        #expect(NewItemNesting.spot(order: ["Trip", "Pack", "Book", "Read", gap, "Run"], gap: gap, pool: pool, asSubtask: false) == .top)
        let besidePack = NewItemNesting.spot(order: ["Trip", "Pack", gap, "Book", "Read", "Run"], gap: gap, pool: pool, asSubtask: false)
        #expect(besidePack == NewItemNesting.Spot(parent: "Trip", depth: 1, index: 1))
    }

    @Test func onTheRightItIsTheRowAbovesFirstSubtask() {
        let under = NewItemNesting.spot(order: ["Trip", "Pack", gap, "Book", "Read", "Run"], gap: gap, pool: pool, asSubtask: true)
        #expect(under == NewItemNesting.Spot(parent: "Pack", depth: 2, index: 0))
    }

    @Test func aHabitAndTheTopOfThePoolTakeNoSubtask() {
        #expect(NewItemNesting.spot(order: [gap, "Trip"], gap: gap, pool: pool, asSubtask: true) == .top)
        #expect(NewItemNesting.spot(order: ["Run", gap], gap: gap, pool: pool, asSubtask: true) == .top)
    }

    @Test func theRightThirdOfThePool() {
        #expect(NewItemNesting.isSubtaskSide(x: 250, poolMinX: 0, poolWidth: 300, share: 1.0 / 3))
        #expect(!NewItemNesting.isSubtaskSide(x: 150, poolMinX: 0, poolWidth: 300, share: 1.0 / 3))
    }
}
