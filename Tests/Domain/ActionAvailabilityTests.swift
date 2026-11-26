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
        DayItem(task: task, state: state, problems: [])
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

    /// A twice-a-day habit done once is still on today's timeline: Skip today puts off its second time too.
    @Test func skipTodayStaysOnATwiceADayHabitDoneOnce() {
        #expect(full.entries(habitMenu, for: item(twiceADay("Water"), .marked(.done))).map(\.action) == [.unmark, .done, .skipToday])
        #expect(full.entries(habitMenu, for: item(twiceADay("Water"), .marked(.twice))).map(\.action) == [.unmark, .done])
        #expect(full.entries(habitMenu, for: item(makeHabit("Walk"), .marked(.done))).map(\.action) == [.unmark, .done])
    }

    /// Twice is offered to twice-a-day habits (and to a day already marked Twice), never to other habits.
    @Test func twiceIsForTwiceADayHabits() {
        #expect(full.entries(habitDayMenu, for: item(makeHabit("Walk"))).map(\.action) == [.partial, .done])
        #expect(full.entries(habitDayMenu, for: item(twiceADay("Water"))).map(\.action) == [.partial, .done, .twice])
        let marked = full.entries(habitDayMenu, for: item(makeHabit("Walk"), .marked(.twice)))
        #expect(marked.map(\.action) == [.unmark, .partial, .done, .twice])
        #expect(marked.first { $0.action == .twice }?.isCurrent == true)
    }

    @Test func aQuantityHabitOffersAnAmountAndPartial() {
        let habit = makeHabit("Walk") { $0.habit.quantity = HabitQuantity(maximum: 10, step: 1) }
        let actions = TestConfig.actions.menus[ActionMenu.context(of: habit)].actions
        #expect(full.entries(actions, for: item(habit)).map(\.action) == [.setAmount, .partial, .skipToday])
        let attempted = full.entries(actions, for: item(habit, .marked(.partial)))
        #expect(attempted.map(\.action) == [.setAmount, .partial, .unmark])
        #expect(attempted.first { $0.action == .partial }?.isCurrent == true)
    }

    /// A store without a link to its own app has no Open in Obsidian; the rest of the menu stays.
    @Test func openInObsidianNeedsTheStoreToOpenItsItems() {
        let page: [ActionID] = [.archive, .openInObsidian, .delete]
        let withoutLinks = ActionAvailability(capabilities: StoreCapabilities(opensExternally: false, hasTrash: true))
        #expect(full.entries(page, for: nil).map(\.action) == page)
        #expect(withoutLinks.entries(page, for: nil).map(\.action) == [.archive, .delete])
    }

    // MARK: - Swipes (actions.json → swipes)

    private func swipes(_ kind: ActionSwipes, _ item: DayItem?, isToday: Bool = true) -> (leading: [ActionID], trailing: [ActionID]) {
        let availability = ActionAvailability(capabilities: full.capabilities, isToday: isToday)
        let definition = TestConfig.actions.swipes[kind]
        return (availability.swipe(definition.leading, for: item), availability.swipe(definition.trailing, for: item))
    }

    /// What was set aside at the bottom of the morning review comes back with a swipe to the left, in the grey of Not
    /// today; to the right it has nothing (D-186).
    @Test func aSetAsideNoteComesBackWithAGreySwipeToTheLeft() {
        for (kind, action) in [(ActionSwipes.setAside, ActionID.returnToToday), (.setAsideTomorrow, .returnTomorrow)] {
            #expect(TestConfig.actions.swipes[kind].leading == [.done])
            #expect(TestConfig.actions.swipes[kind].trailing == [action])
            #expect(TestConfig.actions.definition(action).swipeTint == TestConfig.actions.definition(.notToday).swipeTint)
        }
    }

    /// In a list a swipe to the right is Done, to the left Delete; a done task offers Return instead of Done.
    @Test func aTaskSwipesRightToDoneAndLeftToDelete() {
        #expect(swipes(.task, item(makeTask("Report"))).leading == [.done])
        #expect(swipes(.task, item(makeTask("Report"))).trailing == [.delete])
        #expect(swipes(.task, item(makeTask("Report", status: .done), .marked(.done))).leading == [.returnFromDone])
    }

    /// Done as the menu has it: a habit done today has no Done to swipe, a twice-a-day one done once swipes on to Twice.
    @Test func aHabitSwipesDoneUntilTheDayIsMarked() {
        #expect(swipes(.habit, item(makeHabit("Walk"))).leading == [.done])
        #expect(swipes(.habit, item(makeHabit("Walk"), .marked(.done))).leading.isEmpty)
        #expect(swipes(.habit, item(twiceADay("Water"), .marked(.done))).leading == [.done])
        #expect(swipes(.habit, item(makeHabit("Walk"))).trailing == [.delete])
    }

    /// Soon: a swipe to the left has exactly one button, Not today for a task and Skip today for a habit, both gray; no
    /// Delete there.
    @Test func soonSwipesOneGrayButtonToTheLeft() {
        #expect(swipes(.review, item(makeTask("Report"))).trailing == [.notToday])
        #expect(swipes(.review, item(makeHabit("Walk"))).trailing == [.skipToday])
        #expect(swipes(.review, item(makeHabit("Bins") { $0.habit.repeatable = true })).trailing == [.skipToday])
        #expect(TestConfig.actions.definition(.notToday).swipeTint == ColorToken.swipeNeutral.rawValue)
        #expect(TestConfig.actions.definition(.skipToday).swipeTint == ColorToken.swipeNeutral.rawValue)
        // To the right Done, blue, in the review and in the Lists tab's lists (subtasks are made by carrying a row
        // over the list's right part now, not by a swipe).
        #expect(swipes(.review, item(makeTask("Report"))).leading == [.done])
        #expect(swipes(.listTask, item(makeTask("Report"))) == ([.done], [.delete]))
        #expect(TestConfig.actions.definition(.done).swipeTint == ColorToken.accent.rawValue)
        #expect(TestConfig.actions.definition(.indent).swipeTint == ColorToken.swipeNeutral.rawValue)
    }

    /// The archive and the trash put a note back with a swipe to the right; to the left the archive's go to the trash
    /// (the trash's own, deleted for good, is the trash page's).
    @Test func theArchiveAndTheTrashRestoreToTheRight() {
        #expect(swipes(.archivedTask, item(makeTask("Old", status: .archived))) == ([.restoreThisWeek], [.delete]))
        #expect(swipes(.archivedHabit, item(makeHabit("Old"))) == ([.restoreHabit], [.delete]))
        #expect(swipes(.trash, nil) == ([.restoreFromTrash], []))
    }

    /// Unworm only for a member of the shown day's worm.
    @Test func unwormForAWormMember() {
        let pool = ActionAvailability(capabilities: full.capabilities, worms: [DayWorm(id: "w", members: ["Milk", "Bank"])])
        #expect(pool.isAvailable(.unworm, for: item(makeTask("Bank"))))
        #expect(!pool.isAvailable(.unworm, for: item(makeTask("Report"))))
    }
}
