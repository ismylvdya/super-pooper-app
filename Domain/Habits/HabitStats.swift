import Foundation

/// Soft statistics of one habit: streaks, shares of recent periods, counts and distributions.
/// Today counts only once it is marked (an unmarked today is not over yet). A harmful habit
/// counts clean days instead of marked ones.
struct HabitStats: Sendable {
    struct Streak: Hashable, Sendable {
        let length: Int
        let first: LocalDate
        let last: LocalDate
    }

    /// The share of a recent period (`HabitStatsRules.shareWindowsDays`).
    struct RecentShare: Hashable, Sendable {
        let days: Int
        let share: Double?
    }

    struct MonthCount: Hashable, Sendable {
        let year: Int
        let month: Int
        let count: Int
    }

    /// Streaks count weeks that reached the goal for weekly-goal habits, days otherwise.
    let streakUnit: StreakUnit
    let currentStreak: Int
    let longestStreak: Streak?
    let recentShares: [RecentShare]
    let allTime: Double?
    let doneCount: Int
    let partialCount: Int
    let twiceCount: Int
    /// Marked days per weekday, all time.
    let byWeekday: [Weekday: Int]
    /// Marked days per month, oldest first: from the earliest marked month of the last `HabitStatsRules.months` to this
    /// one (this month alone with no marks), months with no marks between them included.
    let byMonth: [MonthCount]

    enum StreakUnit: Sendable { case days, weeks }

    init(task: TaskItem, today: LocalDate, days: DayBoundary, rules: HabitStatsRules) {
        let history = HabitHistory(task: task, days: days)
        let start = history.start(today: today)
        let days = start <= today ? (0...start.days(until: today)).map { start.adding(days: $0) } : []
        let counted = days.filter { $0 < today || history.mark(on: $0) != nil || task.habit.harmful }

        if case .weeklyGoal(let goal) = task.habit.skipRule {
            streakUnit = .weeks
            let weeks = Self.weekResults(history: history, start: start, today: today, goal: goal, rules: rules)
            currentStreak = Self.trailingRun(weeks.map(\.reached))
            longestStreak = Self.longestRun(weeks.map { ($0.monday, $0.reached) }, lastDay: \.weekEnd)
        } else {
            streakUnit = .days
            // Allowed skips neither count nor break a streak; only missed days do.
            let missed = history.missedDays(through: today.adding(days: -1), today: today)
            let usesSkips = task.habit.skipRule.allowsSkips
            let flags = counted.filter(history.isScheduled).compactMap { day -> (LocalDate, Bool)? in
                if usesSkips, history.mark(on: day) == nil, !missed.contains(day) { return nil }
                return (day, Self.isGood(day, history: history))
            }
            currentStreak = Self.trailingRun(flags.map(\.1))
            longestStreak = Self.longestRun(flags, lastDay: { $0 })
        }

        recentShares = rules.shareWindowsDays.map { window in
            RecentShare(days: window, share: Self.share(of: counted.filter { $0 > today.adding(days: -window) }, history: history, rules: rules))
        }
        allTime = Self.share(of: counted, history: history, rules: rules)

        let marked = days.compactMap { day in history.mark(on: day).map { (day, $0) } }
        doneCount = marked.filter { $0.1 == .done }.count
        partialCount = marked.filter { $0.1 == .partial }.count
        twiceCount = marked.filter { $0.1 == .twice }.count
        byWeekday = Dictionary(grouping: marked.map(\.0), by: \.weekday).mapValues(\.count)
        let months = (0..<rules.months).reversed().map { back in
            var month = today.month - back
            var year = today.year
            while month < 1 { month += 12; year -= 1 }
            return MonthCount(year: year, month: month, count: marked.filter { $0.0.year == year && $0.0.month == month }.count)
        }
        byMonth = Array(months.drop { $0.count == 0 && $0 != months.last })
    }

    /// A good habit's day counts when marked; a harmful habit's day when it stayed clean.
    private static func isGood(_ day: LocalDate, history: HabitHistory) -> Bool {
        history.options.harmful ? history.mark(on: day) == nil : history.mark(on: day) != nil
    }

    /// Units over what the scheduled days could give (a weekly goal spreads the goal over the days).
    private static func share(of days: [LocalDate], history: HabitHistory, rules: HabitStatsRules) -> Double? {
        let scheduled = days.filter(history.isScheduled)
        guard !scheduled.isEmpty else { return nil }
        if history.options.harmful {
            return Double(scheduled.filter { history.mark(on: $0) == nil }.count) / Double(scheduled.count)
        }
        let units = scheduled.map { history.units(on: $0, rules: rules) }.reduce(0, +)
        let possible: Double
        if case .weeklyGoal(let goal) = history.options.skipRule {
            possible = Double(goal) * Double(days.count) / 7
        } else {
            possible = Double(scheduled.count) * rules.unitsPerDay(history.options)
        }
        return possible > 0 ? min(units / possible, 1) : nil
    }

    private struct WeekResult {
        let monday: LocalDate
        let reached: Bool
    }

    /// Finished weeks, plus the current one only if its goal is already reached.
    private static func weekResults(history: HabitHistory, start: LocalDate, today: LocalDate, goal: Int,
                                    rules: HabitStatsRules) -> [WeekResult] {
        var monday = start.weekStart
        var result: [WeekResult] = []
        while monday <= today {
            let reached = history.weekUnits(containing: monday, today: today, rules: rules) >= Double(goal)
            let finished = monday.weekEnd < today
            if finished || reached { result.append(WeekResult(monday: monday, reached: reached)) }
            monday = monday.adding(days: 7)
        }
        return result
    }

    private static func trailingRun(_ flags: [Bool]) -> Int {
        flags.reversed().prefix { $0 }.count
    }

    private static func longestRun(_ flags: [(LocalDate, Bool)], lastDay: (LocalDate) -> LocalDate) -> Streak? {
        var best: Streak?
        var runStart: LocalDate?
        var length = 0
        for (day, good) in flags {
            if good {
                if runStart == nil { runStart = day }
                length += 1
                if let first = runStart, length > (best?.length ?? 0) {
                    best = Streak(length: length, first: first, last: lastDay(day))
                }
            } else {
                runStart = nil
                length = 0
            }
        }
        return best
    }
}
