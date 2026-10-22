import Foundation

/// One day cell of a habit grid. No streaks and no "missed" pressure: unmarked past days are
/// just empty; Partially and Twice look different from Done.
enum HabitCell: Hashable, Sendable {
    case done
    case partial
    case twice
    /// Scheduled but not marked (past or today).
    case open
    case notScheduled
    case future
}

/// Weeks (Monday…Sunday columns) of a recurring task's marks, ending with the current week.
struct HabitGrid: Sendable {
    let weeks: [[HabitCell]]

    init(task: TaskNote, weekCount: Int, today: LocalDate, calendar: Calendar) {
        let occurrence = TaskOccurrence(calendar: calendar)
        let instances = HabitInstances(task: task)
        let lastSunday = today.adding(days: Weekday.sunday.rawValue - today.weekday.rawValue)
        let firstMonday = lastSunday.adding(days: -(weekCount * 7) + 1)
        weeks = (0..<weekCount).map { week in
            (0..<7).map { offset in
                let day = firstMonday.adding(days: week * 7 + offset)
                if day > today { return .future }
                switch instances.mark(on: day) {
                case .done: return .done
                case .partial: return .partial
                case .twice: return .twice
                case nil: return occurrence.occurs(task, on: day) ? .open : .notScheduled
                }
            }
        }
    }
}
