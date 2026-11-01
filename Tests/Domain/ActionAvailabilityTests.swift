import Foundation
import Testing
@testable import SuperPooperApp

/// Which actions a menu offers for an item, and which is its current mark.
struct ActionAvailabilityTests {
    private let full = ActionAvailability(capabilities: StoreCapabilities(opensExternally: true, hasTrash: true))
    private let poolMenu: [ActionID] = [.done, .unmark, .notToday, .delete]
    private let habitMenu: [ActionID] = [.unmark, .done, .skipToday]
    private let habitDayMenu: [ActionID] = [.unmark, .partial, .done, .twice]

    private func item(_ task: TaskItem, _ state: DayItemState = .open) -> DayItem {
        DayItem(task: task, state: state, blockers: [], problems: [])
    }

    private func twiceADay(_ name: String) -> TaskItem { makeHabit(name) { $0.habit.twiceADay = true } }

    @Test func anOpenTaskOffersDoneNotTodayAndDelete() {
        let entries = full.entries(poolMenu, for: item(makeTask("Report")))
        #expect(entries.map(\.action) == [.done, .notToday, .delete])
        #expect(entries.allSatisfy { !$0.isCurrent })
    }

    /// Skip today and Not today belong to today's page.
    @Test func anotherDayOffersNeitherSkipNorNotToday() {
        let otherDay = ActionAvailability(capabilities: full.capabilities, isToday: false)
        #expect(otherDay.entries(poolMenu, for: item(makeTask("Report"))).map(\.action) == [.done, .delete])
        #expect(otherDay.entries(habitMenu, for: item(makeHabit("Water"))).map(\.action) == [.done])
    }

    @Test func aDoneTaskOffersUnmarkAndShowsDoneAsCurrent() {
        let entries = full.entries(poolMenu, for: item(makeTask("Report"), .marked(.done)))
        #expect(entries.map(\.action) == [.done, .unmark, .delete])
        #expect(entries.first { $0.action == .done }?.isCurrent == true)
    }

    /// Without Twice in the menu, Done on a twice-a-day habit done once goes on to Twice: it stays selectable.
    @Test func doneStaysSelectableOnATwiceADayHabitDoneOnce() {
        let done = item(twiceADay("Water"), .marked(.done))
        #expect(full.entries(habitMenu, for: done).first { $0.action == .done }?.isCurrent == false)
        #expect(full.entries(habitDayMenu, for: done).first { $0.action == .done }?.isCurrent == true)
        #expect(full.entries(habitMenu, for: item(makeHabit("Walk"), .marked(.done))).first { $0.action == .done }?.isCurrent == true)
    }

    /// Twice is offered to twice-a-day habits (and to a day already marked Twice), never to other habits.
    @Test func twiceIsForTwiceADayHabits() {
        #expect(full.entries(habitDayMenu, for: item(makeHabit("Walk"))).map(\.action) == [.partial, .done])
        #expect(full.entries(habitDayMenu, for: item(twiceADay("Water"))).map(\.action) == [.partial, .done, .twice])
        let marked = full.entries(habitDayMenu, for: item(makeHabit("Walk"), .marked(.twice)))
        #expect(marked.map(\.action) == [.unmark, .partial, .done, .twice])
        #expect(marked.first { $0.action == .twice }?.isCurrent == true)
    }

    /// A store without a link to its own app has no Open in Obsidian; the rest of the menu stays.
    @Test func openInObsidianNeedsTheStoreToOpenItsItems() {
        let page: [ActionID] = [.archive, .openInObsidian, .delete]
        let withoutLinks = ActionAvailability(capabilities: StoreCapabilities(opensExternally: false, hasTrash: true))
        #expect(full.entries(page, for: nil).map(\.action) == page)
        #expect(withoutLinks.entries(page, for: nil).map(\.action) == [.archive, .delete])
    }
}
