import Foundation
import Testing
@testable import SuperPooper

/// Streaks, shares, missed days and the weekly goal (today = Wednesday 2026-10-21).
@Suite("Habit statistics")
struct HabitStatsTests {
    private let today = LocalDate(TestCalendar.wednesday)

    /// A daily habit created `days` days ago with marks `offsets` days before today (0 = today).
    private func habit(createdDaysAgo days: Int = 30, done: [Int] = [], partial: [Int] = [], twice: [Int] = [],
                       _ configure: (inout TaskNote) -> Void = { _ in }) -> TaskNote {
        let start = today.adding(days: -days)
        var task = makeTask("Habit", status: .habit, created: start.isoString)
        task.recurrenceRaw = "DTSTART:\(start.isoString.replacingOccurrences(of: "-", with: ""));FREQ=DAILY"
        task.recurrence = try? RecurrenceRule.parse(task.recurrenceRaw ?? "").get()
        let day = { (offset: Int) in self.today.adding(days: -offset) }
        task.completeInstances = (done + partial + twice).map(day)
        task.partialInstances = partial.map(day)
        task.twiceInstances = twice.map(day)
        configure(&task)
        return task
    }

    private func stats(_ task: TaskNote) -> HabitStats { HabitStats(task: task, today: today, days: TestCalendar.days) }

    @Test func currentStreakStartsYesterdayWhileTodayIsOpen() {
        #expect(stats(habit(done: [1, 2, 3, 5])).currentStreak == 3)
        #expect(stats(habit(done: [0, 1, 2, 3, 5])).currentStreak == 4)
    }

    @Test func longestStreakHasItsDates() {
        let longest = stats(habit(done: [1, 2, 10, 11, 12, 13])).longestStreak
        #expect(longest?.length == 4)
        #expect(longest?.first == today.adding(days: -13) && longest?.last == today.adding(days: -10))
    }

    @Test func sharesCountPartialAsHalfAndSkipAnOpenToday() {
        let last7 = stats(habit(done: [1, 2, 3], partial: [4])).last7
        // Six finished days (today is open): 3 + 0.5 out of 6.
        #expect(last7.map { abs($0 - 3.5 / 6) < 0.0001 } == true)
    }

    @Test func twiceCountsDoubleOnlyWhenAskedTo() {
        let plain = habit(createdDaysAgo: 1, twice: [1]) { $0.habit.twiceADay = true }
        #expect(stats(plain).allTime == 1)
        let double = habit(createdDaysAgo: 1, done: [1]) { task in
            task.habit.twiceADay = true
            task.habit.twiceCountsDouble = true
        }
        #expect(stats(double).allTime == 0.5)
    }

    @Test func harmfulHabitsCountCleanDays() {
        let smoking = habit(createdDaysAgo: 5, done: [3]) { $0.habit.harmful = true }
        let result = stats(smoking)
        #expect(result.currentStreak == 3)  // today, yesterday, the day before
        #expect(result.longestStreak?.length == 3)
    }

    @Test func allowedSkipsDoNotBreakAStreakButMissedDaysDo() {
        let task = habit(createdDaysAgo: 10, done: [1, 3, 4, 8]) { $0.habit.allowedSkips = 1 }
        let history = HabitHistory(task: task, days: TestCalendar.days)
        let missed = history.missedDays(through: today.adding(days: -1), today: today)
        // Runs: 10–9 (9 is the second skip), 7–5 (6 and 5 are beyond one skip), 2 (allowed).
        #expect(missed == Set([9, 6, 5].map { today.adding(days: -$0) }))
        #expect(stats(task).currentStreak == 3)
    }

    @Test func weeklyGoalStreakCountsWeeks() {
        // Weeks (Mon–Sun) before this one: 12–18 Oct and 5–11 Oct, three marks each.
        let task = habit(createdDaysAgo: 16, done: [3, 4, 5, 10, 11, 12]) { $0.habit.weeklyGoal = 3 }
        let result = stats(task)
        #expect(result.streakUnit == .weeks)
        #expect(result.currentStreak == 2)
    }

    @Test func weekUnitsCountThisWeekOnly() {
        let task = habit(done: [0, 1, 2, 3])  // Wed, Tue, Mon this week; Sun last week
        #expect(HabitHistory(task: task, days: TestCalendar.days).weekUnits(containing: today, today: today) == 3)
    }

    @Test func gridMarksMissedDays() {
        let task = habit(createdDaysAgo: 10, done: [8]) { $0.habit.allowedSkips = 2 }
        let grid = HabitGrid(task: task, weekCount: 2, today: today, days: TestCalendar.days)
        let cells = grid.weeks.flatMap { $0 }
        #expect(cells.first { $0.date == today.adding(days: -4) }?.cell == .missed)
        #expect(cells.first { $0.date == today.adding(days: -7) }?.cell == .open)
    }
}
