import Foundation
import Testing
@testable import SuperPooperApp

/// Streaks, shares, missed days and the weekly goal (today = Wednesday 2026-10-21).
@Suite("Habit statistics")
struct HabitStatsTests {
    private let today = LocalDate(TestCalendar.wednesday)

    /// A daily habit created `days` days ago with marks `offsets` days before today (0 = today).
    private func habit(createdDaysAgo days: Int = 30, done: [Int] = [], partial: [Int] = [], twice: [Int] = [],
                       _ configure: (inout TaskItem) -> Void = { _ in }) -> TaskItem {
        let start = today.adding(days: -days)
        var task = makeTask("Habit", status: .habit, created: start.isoString)
        task.recurrence = try? RecurrenceCodec.parse("DTSTART:\(start.isoString.replacingOccurrences(of: "-", with: ""));FREQ=DAILY").get()
        let day = { (offset: Int) in self.today.adding(days: -offset) }
        task.marks = Dictionary(uniqueKeysWithValues: done.map { (day($0), HabitMark.done) } + partial.map { (day($0), .partial) }
            + twice.map { (day($0), .twice) })
        configure(&task)
        return task
    }

    private let rules = TestConfig.rules.habits.stats

    private func stats(_ task: TaskItem) -> HabitStats { HabitStats(task: task, today: today, days: TestCalendar.days, rules: rules) }

    @Test func quantityAverageIncludesUnmarkedAndPartialScheduledDays() {
        let task = habit(createdDaysAgo: 3) {
            $0.habit.quantity = HabitQuantity(maximum: 10, step: 3)
            $0.quantities = [today: .partial, today.adding(days: -1): .amount(4),
                             today.adding(days: -2): .amount(0), today.adding(days: 1): .amount(10)]
        }
        let stats = HabitQuantityStats(task: task, today: today, days: TestCalendar.days)
        #expect(stats.total == 4 && stats.average == 1 && stats.maximum == 4)
        #expect(stats.recordedDays == 2 && stats.attemptedDays == 1)
        #expect(task.habit.quantityTracking?.values == [1, 4, 7, 10])
        #expect(task.habit.quantityTracking?.accepts(0) == false)
        #expect(task.habit.quantityTracking?.accepts(1) == true)
    }

    @Test func quantityGoalsCountCompletedDaysAndAllowedSkipsCountUnmarkedDays() {
        var task = habit(createdDaysAgo: 8) {
            $0.habit.quantity = HabitQuantity(maximum: 10, step: 1)
            $0.habit.twiceADay = true
            $0.habit.twiceCountsDouble = true
            $0.habit.weeklyGoal = 2
            $0.quantities = [today.adding(days: -2): .amount(10), today.adding(days: -1): .partial]
        }
        let history = HabitHistory(task: task, days: TestCalendar.days)
        #expect(history.weekUnits(containing: today, today: today, rules: rules) == 1)
        #expect(rules.unitsPerDay(task.habit) == 1 && stats(task).currentStreak == 0)
        task.quantities?[today] = .amount(1)
        #expect(stats(task).currentStreak == 1)

        task.habit.weeklyGoal = nil
        task.habit.allowedSkips = 1
        let withSkips = HabitHistory(task: task, days: TestCalendar.days)
        let missed = withSkips.missedDays(through: today, today: today)
        #expect(!missed.contains(today.adding(days: -8)))
        #expect(missed.contains(today.adding(days: -7)))
        #expect(!missed.contains(today.adding(days: -1)))
    }

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
        let last7 = stats(habit(done: [1, 2, 3], partial: [4])).recentShares.first { $0.days == 7 }?.share
        // Six finished days (today is open): 3 + 0.5 out of 6.
        #expect(last7.map { abs($0 - 3.5 / 6) < 0.0001 } == true)
    }

    /// From the earliest month with a mark to this one, the empty ones between them included.
    @Test func monthsRunFromTheEarliestMarkedToThisOne() {
        // Today is 2026-10-21: 1 day ago is October, 60 days ago August; September has no marks.
        let months = stats(habit(createdDaysAgo: 200, done: [1, 2, 60])).byMonth
        #expect(months.map(\.month) == [8, 9, 10])
        #expect(months.map(\.count) == [1, 0, 2])
    }

    @Test func withNoMarksOnlyThisMonthShows() {
        #expect(stats(habit()).byMonth.map(\.month) == [10])
    }

    /// The numbers come from `rules.json` → `habits.stats`: the windows, what Partially and a double Twice are worth,
    /// the months of the bars.
    @Test func theNumbersComeFromTheRules() {
        let custom = HabitStatsRules(partialUnits: 0.25, twiceUnits: 3, shareWindowsDays: [3], months: 2)
        let result = HabitStats(task: habit(done: [1, 25, 60], partial: [2]), today: today, days: TestCalendar.days, rules: custom)
        #expect(result.recentShares.map(\.days) == [3])
        // Two finished days in the window (today is open): 1 + 0.25 out of 2.
        #expect(result.recentShares.first?.share == 0.625)
        #expect(result.byMonth.count == 2)
        var options = HabitOptions()
        options.twiceADay = true
        options.twiceCountsDouble = true
        #expect(custom.units(of: .twice, options) == 3)
        #expect(TestConfig.rules.habits.stats.units(of: .partial, options) == 0.5)
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
        #expect(HabitHistory(task: task, days: TestCalendar.days).weekUnits(containing: today, today: today, rules: rules) == 3)
    }

    @Test func gridMarksMissedDays() {
        let task = habit(createdDaysAgo: 10, done: [8]) { $0.habit.allowedSkips = 2 }
        let grid = HabitGrid(task: task, weekCount: 2, today: today, days: TestCalendar.days)
        let cells = grid.weeks.flatMap { $0 }
        #expect(cells.first { $0.date == today.adding(days: -4) }?.cell == .missed)
        #expect(cells.first { $0.date == today.adding(days: -7) }?.cell == .open)
    }
}
