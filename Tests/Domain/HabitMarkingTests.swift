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
        #expect(HabitMarking.notificationMark(.done, current: nil, remindersPerDay: 2) == .done)
        #expect(HabitMarking.notificationMark(.done, current: .done, remindersPerDay: 2) == .twice)
        #expect(HabitMarking.notificationMark(.done, current: .twice, remindersPerDay: 2) == .twice)
    }

    @Test func aPartialDayBecomesTwiceOnTheNextDone() {
        #expect(HabitMarking.notificationMark(.done, current: .partial, remindersPerDay: 2) == .twice)
    }

    @Test func withOneReminderDoneStaysDone() {
        #expect(HabitMarking.notificationMark(.done, current: .done, remindersPerDay: 1) == .done)
        #expect(HabitMarking.notificationMark(.done, current: .partial, remindersPerDay: 1) == .partial)
    }

    @Test func aDayWithSeveralRemindersClosesOnlyWithTwice() {
        #expect(!HabitMarking.isDayClosed(nil, twiceADay: false, remindersPerDay: 1))
        #expect(HabitMarking.isDayClosed(.done, twiceADay: false, remindersPerDay: 1))
        #expect(!HabitMarking.isDayClosed(.done, twiceADay: false, remindersPerDay: 2))
        #expect(!HabitMarking.isDayClosed(.partial, twiceADay: true, remindersPerDay: 0))
        #expect(HabitMarking.isDayClosed(.twice, twiceADay: false, remindersPerDay: 2))
    }

    @Test func partiallyNeverDowngrades() {
        #expect(HabitMarking.notificationMark(.partial, current: nil, remindersPerDay: 2) == .partial)
        #expect(HabitMarking.notificationMark(.partial, current: .done, remindersPerDay: 2) == .done)
        #expect(HabitMarking.notificationMark(.partial, current: .twice, remindersPerDay: 2) == .twice)
    }

    @Test func aPastDayIsMarkedOnThatDay() {
        let habit = makeHabit("Read", status: .habit)
        let yesterday = LocalDate("2026-10-20")
        let changes = TaskMarking(today: LocalDate(TestCalendar.wednesday)).changes(marking: habit, as: .partial, on: yesterday)
        #expect(changes == [.markInstance(day: yesterday, mark: .partial)])
        let marked = habit.applying(changes)
        #expect(marked.completeInstances == [yesterday] && marked.partialInstances == [yesterday])
    }

    @Test func habitOrderKeepsTheDraggedOrderThenAlphabetical() {
        let names = HabitOrder.sorted(["b", "a", "d", "c"].map { makeHabit($0) }, order: ["d", "b"]).map(\.name)
        #expect(names == ["d", "b", "a", "c"])
    }
}
