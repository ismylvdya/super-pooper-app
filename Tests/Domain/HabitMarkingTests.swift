import Foundation
import Testing
@testable import SuperPooperApp

/// Taps, notification buttons and marks on past days.
@Suite("Habit marking")
struct HabitMarkingTests {
    @Test func tapCyclesThroughDoneAndBack() {
        #expect(HabitMarking.next(after: nil, twiceADay: false) == .done)
        #expect(HabitMarking.next(after: .done, twiceADay: false) == nil)
        #expect(HabitMarking.next(after: .partial, twiceADay: false) == nil)
    }

    @Test func twiceADayTapGoesThroughTwice() {
        #expect(HabitMarking.next(after: .done, twiceADay: true) == .twice)
        #expect(HabitMarking.next(after: .partial, twiceADay: true) == .twice)
        #expect(HabitMarking.next(after: .twice, twiceADay: true) == nil)
    }

    /// Two reminders a day make a habit twice-a-day without the option: tap and menus offer Twice.
    @Test func twoRemindersADayMeanTwiceADay() {
        let two = makeTask("Push-ups", status: .habit) { $0.reminderTimes = [LocalTime("11:45"), LocalTime("17:45")] }
        let one = makeTask("Water", status: .habit) { $0.reminderTimes = [LocalTime("09:00")] }
        #expect(two.isTwiceADay && !one.isTwiceADay)
        #expect(HabitMarking.next(after: .done, twiceADay: two.isTwiceADay) == .twice)
    }

    @Test func doneFromTodayOnATwiceHabitDoneOnceIsTwice() {
        #expect(HabitMarking.menuDone(current: .done, twiceADay: true) == .twice)
        #expect(HabitMarking.menuDone(current: .done, twiceADay: false) == .done)
        #expect(HabitMarking.menuDone(current: nil, twiceADay: true) == .done)
    }

    @Test func secondDoneFromATwoReminderDayIsTwice() {
        #expect(HabitMarking.notificationMark(.done, current: nil, twiceADay: true) == .done)
        #expect(HabitMarking.notificationMark(.done, current: .done, twiceADay: true) == .twice)
        #expect(HabitMarking.notificationMark(.done, current: .twice, twiceADay: true) == .twice)
    }

    @Test func aPartialDayBecomesTwiceOnTheNextDone() {
        #expect(HabitMarking.notificationMark(.done, current: .partial, twiceADay: true) == .twice)
    }

    @Test func withOneReminderDoneStaysDone() {
        #expect(HabitMarking.notificationMark(.done, current: .done, twiceADay: false) == .done)
        #expect(HabitMarking.notificationMark(.done, current: .partial, twiceADay: false) == .partial)
    }

    /// One rule of twice a day (D-037): a habit with the Twice option and a single reminder also takes Twice on the
    /// notification's second Done, as in the menus. It used to count only the reminders and stayed Done.
    @Test func theTwiceOptionWithOneReminderMakesTheSecondDoneTwice() {
        let habit = makeTask("Stretch", status: .habit) { $0.reminderTimes = [LocalTime("09:00")]; $0.habit.twiceADay = true }
        #expect(HabitMarking.notificationMark(.done, current: .done, twiceADay: habit.isTwiceADay) == .twice)
        #expect(!HabitMarking.isDayClosed(.done, twiceADay: habit.isTwiceADay))
    }

    @Test func aDayWithSeveralRemindersClosesOnlyWithTwice() {
        let two = makeTask("Push-ups", status: .habit) { $0.reminderTimes = [LocalTime("11:45"), LocalTime("17:45")] }
        #expect(!HabitMarking.isDayClosed(nil, twiceADay: false))
        #expect(HabitMarking.isDayClosed(.done, twiceADay: false))
        #expect(!HabitMarking.isDayClosed(.done, twiceADay: two.isTwiceADay))
        #expect(!HabitMarking.isDayClosed(.partial, twiceADay: true))
        #expect(HabitMarking.isDayClosed(.twice, twiceADay: two.isTwiceADay))
    }

    @Test func partiallyNeverDowngrades() {
        #expect(HabitMarking.notificationMark(.partial, current: nil, twiceADay: true) == .partial)
        #expect(HabitMarking.notificationMark(.partial, current: .done, twiceADay: true) == .done)
        #expect(HabitMarking.notificationMark(.partial, current: .twice, twiceADay: true) == .twice)
    }

    @Test func aPastDayIsMarkedOnThatDay() {
        let habit = makeHabit("Read", status: .habit)
        let yesterday = LocalDate("2026-10-20")
        let changes = TaskMarking(today: LocalDate(TestCalendar.wednesday)).changes(marking: habit, as: .partial, on: yesterday)
        #expect(changes == [.mark(.partial, on: yesterday)])
        let marked = habit.applying(changes)
        #expect(marked.marks == [yesterday: .partial])
    }

    @Test func habitOrderKeepsTheDraggedOrderThenAlphabetical() {
        let names = HabitOrder.sorted(["b", "a", "d", "c"].map { makeHabit($0) }, order: ["d", "b"]).map(\.name)
        #expect(names == ["d", "b", "a", "c"])
    }
}
