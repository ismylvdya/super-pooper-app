import Foundation

/// The part of the day a habit belongs to; the pool lifts habits of the current part.
enum HabitTimeOfDay: String, Codable, CaseIterable, Sendable {
    case morning
    case day
    case evening
}

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

/// Habit settings stored in the note next to the TaskNotes fields (`habit_color`, `harmful`, …).
struct HabitOptions: Hashable, Codable, Sendable {
    /// `#RRGGBB`, `nil` = the habit color from tokens.
    var color: String?
    /// A habit to get rid of: a mark means "it happened", streaks count clean days.
    var harmful = false
    /// Whether the habit appears in Today's pool and timeline. Notes written before the
    /// switch existed have no key and stay visible.
    var showInToday = true
    var timeOfDay: HabitTimeOfDay?
    /// Enables the Twice mark (tap cycles none → done → twice).
    var twiceADay = false
    /// A twice day counts as two toward the goal and the percentages.
    var twiceCountsDouble = false
    var weeklyGoal: Int?
    var allowedSkips: Int?

    var skipRule: HabitSkipRule {
        if let weeklyGoal, weeklyGoal > 0 { return .weeklyGoal(times: weeklyGoal) }
        if let allowedSkips, !harmful { return .missedDays(allowed: max(allowedSkips, 0)) }
        return .none
    }

    /// Marks a single day is worth at most.
    var unitsPerDay: Double { twiceADay && twiceCountsDouble ? 2 : 1 }
}
