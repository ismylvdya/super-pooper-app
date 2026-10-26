import Foundation

/// One day cell of a habit grid. Partially and Twice look different from Done; "missed" exists only
/// for habits with the allowed-skips rule.
enum HabitCell: Hashable, Sendable {
    case done
    case partial
    case twice
    /// Scheduled but not marked (past or today).
    case open
    /// Unmarked beyond the allowed skips in a row.
    case missed
    case notScheduled
    case future
}

/// Weeks of a habit's days as rows (Monday … Sunday), oldest first, ending with the current week.
struct HabitGrid: Sendable {
    struct Day: Hashable, Sendable {
        let date: LocalDate
        let cell: HabitCell
    }

    let weeks: [[Day]]

    init(task: TaskNote, weekCount: Int, today: LocalDate, days: DayBoundary) {
        let history = HabitHistory(task: task, days: days)
        let lastSunday = today.adding(days: Weekday.sunday.rawValue - today.weekday.rawValue)
        let firstMonday = lastSunday.adding(days: -(max(weekCount, 1) * 7) + 1)
        let missed = history.missedDays(through: today.adding(days: -1), today: today)
        weeks = (0..<max(weekCount, 1)).map { week in
            (0..<7).map { offset in
                let day = firstMonday.adding(days: week * 7 + offset)
                return Day(date: day, cell: Self.cell(day, history: history, missed: missed, today: today))
            }
        }
    }

    /// Enough weeks to reach back to the first marked day (plus `extraWeeks`), but at least `minimumWeeks`.
    static func weekCount(for task: TaskNote, today: LocalDate, minimumWeeks: Int, extraWeeks: Int) -> Int {
        let start = HabitInstances(task: task).complete.min() ?? today
        let startMonday = start.adding(days: -(start.weekday.rawValue - 1))
        let weeks = startMonday.days(until: today) / 7 + 1
        return max(minimumWeeks, weeks + extraWeeks)
    }

    private static func cell(_ day: LocalDate, history: HabitHistory, missed: Set<LocalDate>, today: LocalDate) -> HabitCell {
        if day > today { return .future }
        switch history.mark(on: day) {
        case .done: return .done
        case .partial: return .partial
        case .twice: return .twice
        case nil:
            if missed.contains(day) { return .missed }
            return history.isScheduled(day) ? .open : .notScheduled
        }
    }
}
