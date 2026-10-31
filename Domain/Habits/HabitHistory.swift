import Foundation

/// A habit's days as facts: which days are scheduled, how each is marked, which ones count as missed.
struct HabitHistory: Sendable {
    let task: TaskItem
    let days: DayBoundary
    /// Built once: the history asks about every day since the start.
    private let schedule: TaskSchedule

    init(task: TaskItem, days: DayBoundary) {
        self.task = task
        self.days = days
        self.schedule = TaskOccurrence(days: days).schedule(of: task)
    }

    var options: HabitOptions { task.habit }

    func mark(on day: LocalDate) -> HabitMark? { task.mark(on: day) }

    func isScheduled(_ day: LocalDate) -> Bool { schedule.occurs(on: day) }

    /// The first day the habit counts from: its creation or its first mark, whichever is earlier.
    func start(today: LocalDate) -> LocalDate {
        let created = task.created.map(days.day(of:)) ?? today
        return ([created] + task.marks.keys).min() ?? today
    }

    /// What a day is worth toward the goal and the percentages (`HabitStatsRules`: Partially is part of a day, Twice
    /// more than one when the habit counts it double).
    func units(on day: LocalDate, rules: HabitStatsRules) -> Double {
        rules.units(of: mark(on: day), options)
    }

    /// Units marked in the Monday–Sunday week of `day`, up to `today`.
    func weekUnits(containing day: LocalDate, today: LocalDate, rules: HabitStatsRules) -> Double {
        let monday = day.weekStart
        return (0..<7).map { monday.adding(days: $0) }.filter { $0 <= today }.map { units(on: $0, rules: rules) }.reduce(0, +)
    }

    /// Days beyond the allowed run of unmarked scheduled days, from the start up to `through`
    /// (yesterday: today is not over yet). Only the "missed days" rule has them.
    func missedDays(through last: LocalDate, today: LocalDate) -> Set<LocalDate> {
        guard case .missedDays(let allowed) = options.skipRule else { return [] }
        var result: Set<LocalDate> = []
        var run = 0
        var day = start(today: today)
        while day <= last {
            if isScheduled(day) {
                if mark(on: day) == nil {
                    run += 1
                    if run > allowed { result.insert(day) }
                } else {
                    run = 0
                }
            }
            day = day.adding(days: 1)
        }
        return result
    }
}
