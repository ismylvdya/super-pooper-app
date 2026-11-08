import Foundation
import Testing
@testable import SuperPooperApp

/// Which actions Select mode offers for the picked tasks: one that at least one of them can take.
struct BatchAvailabilityTests {
    private let capabilities = StoreCapabilities(opensExternally: true, hasTrash: true)

    private func batch(isToday: Bool = true, worms: [DayWorm] = []) -> BatchAvailability {
        BatchAvailability(single: ActionAvailability(capabilities: capabilities, isToday: isToday, canSelect: true, worms: worms))
    }

    private func item(_ name: String, _ state: DayItemState = .open, depth: Int = 0) -> DayItem {
        DayItem(task: makeTask(name), state: state, problems: [], depth: depth)
    }

    @Test func oneDoneItemAmongOpenOnesStillOffersDone() {
        let items = [item("Milk", .marked(.done)), item("Bank")]
        #expect(batch().isAvailable(.done, for: items))
        #expect(batch().isAvailable(.delete, for: items))
        #expect(!batch().isAvailable(.done, for: []), "nothing picked offers nothing")
    }

    @Test func wormNeedsTwoOpenItems() {
        #expect(batch().isAvailable(.worm, for: [item("Milk"), item("Bank")]))
        #expect(!batch().isAvailable(.worm, for: [item("Milk")]))
        #expect(!batch().isAvailable(.worm, for: [item("Milk"), item("Bank", .marked(.done))]))
        #expect(!batch().isAvailable(.worm, for: [item("Milk"), item("Paint", depth: 1)]), "a subtask stays with its parent")
        let wormed = batch(worms: [DayWorm(id: "w", members: ["Milk", "Bank"])])
        #expect(!wormed.isAvailable(.worm, for: [item("Milk"), item("Bank")]), "already one worm")
        #expect(wormed.isAvailable(.worm, for: [item("Milk"), item("Report")]), "a task joins the worm")
    }

    @Test func unwormOnlyForAWormMember() {
        let wormed = batch(worms: [DayWorm(id: "w", members: ["Milk", "Bank"])])
        #expect(wormed.isAvailable(.unworm, for: [item("Report"), item("Bank")]))
        #expect(!wormed.isAvailable(.unworm, for: [item("Report")]))
        #expect(!batch().isAvailable(.unworm, for: [item("Milk"), item("Bank")]))
    }

    @Test func notTodayOnlyOnToday() {
        #expect(batch().isAvailable(.notToday, for: [item("Milk")]))
        #expect(!batch(isToday: false).isAvailable(.notToday, for: [item("Milk")]))
    }

    @Test func theSelectionMenuSplitsIntoButtonsAndMore() {
        let entries = batch().entries(TestConfig.actions.menus[.selection], for: [item("Milk")])
        #expect(entries.frequent == [.done, .notToday])
        #expect(entries.more == [.start, .highPriority, .moveToList, .newSection, .delete], "one task is no worm")
    }

    /// With a habit picked Skip today stands in for Not today; Delete is for tasks alone, habits never go with it.
    @Test func skipTodayStandsInWithAHabitAndDeleteLeavesHabits() {
        let habit = DayItem(listed: makeHabit("Run"))
        let menu = TestConfig.actions.menus[.selection]
        let mixed = batch().entries(menu, for: [item("Milk"), habit])
        #expect(mixed.frequent == [.done, .skipToday])
        #expect(mixed.more.contains(.delete))
        let habits = batch().entries(menu, for: [habit])
        #expect(habits.frequent == [.done, .skipToday])
        #expect(!habits.more.contains(.delete))
        let targets = BatchAvailability.targets(of: .skipToday, in: [item("Milk"), habit])
        #expect(targets.map(\.action) == [.skipToday, .notToday])
        #expect(BatchAvailability.targets(of: .delete, in: [item("Milk"), habit])[0].items.map(\.id) == ["Milk"])
    }
}
