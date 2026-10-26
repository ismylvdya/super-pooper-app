import Foundation

/// A habit's days as facts: which days are scheduled, how each is marked, which ones count as missed.
struct HabitHistory: Sendable {
    let task: TaskNote
    let days: DayBoundary
    private let instances: HabitInstances
    private let occurrence: TaskOccurrence

    init(task: TaskNote, days: DayBoundary) {
        self.task = task
        self.days = days
        self.instances = HabitInstances(task: task)
        self.occurrence = TaskOccurrence(days: days)
    }

    var options: HabitOptions { task.habit }

    func mark(on day: LocalDate) -> HabitMark? { instances.mark(on: day) }

    func isScheduled(_ day: LocalDate) -> Bool { occurrence.occurs(task, on: day) }

    /// The first day the habit counts from: its creation or its first mark, whichever is earlier.
    func start(today: LocalDate) -> LocalDate {
        let created = task.dateCreated.map(days.day(of:)) ?? today
        return ([created] + instances.complete).min() ?? today
    }

    /// What a day is worth toward the goal and the percentages: Partially is half a day,
    /// Twice is two when the habit counts it double.
    func units(on day: LocalDate) -> Double {
        switch mark(on: day) {
        case nil: 0
        case .partial: 0.5
        case .done: 1
        case .twice: options.unitsPerDay
        }
    }

    /// Units marked in the Monday–Sunday week of `day`, up to `today`.
    func weekUnits(containing day: LocalDate, today: LocalDate) -> Double {
        let monday = day.adding(days: -(day.weekday.rawValue - 1))
        return (0..<7).map { monday.adding(days: $0) }.filter { $0 <= today }.map(units(on:)).reduce(0, +)
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
