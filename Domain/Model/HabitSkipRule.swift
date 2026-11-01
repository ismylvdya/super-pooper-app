import Foundation

/// How a habit counts missed days: not at all, by a run of allowed skips, or by a weekly goal.
enum HabitSkipRule: Hashable, Sendable {
    case none
    /// Up to `allowed` unmarked scheduled days in a row are fine; longer runs are "missed".
    case missedDays(allowed: Int)
    /// `times` marks a week are the goal; days don't count as missed.
    case weeklyGoal(times: Int)

    var allowsSkips: Bool {
        if case .missedDays = self { return true }
        return false
    }
}
