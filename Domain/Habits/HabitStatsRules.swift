import Foundation

/// The numbers of a habit's goal and statistics (`rules.json` → `habits.stats`).
struct HabitStatsRules: Codable, Hashable, Sendable {
    /// What a Partially day is worth toward the goal and the shares.
    let partialUnits: Double
    /// What a Twice day is worth when the habit counts it double (otherwise one, as Done).
    let twiceUnits: Double
    /// The recent periods whose share is shown, in days.
    let shareWindowsDays: [Int]
    /// The by-month bars reach back this many months, this one included.
    let months: Int

    /// What a day can be worth at most.
    func unitsPerDay(_ options: HabitOptions) -> Double {
        options.twiceADay && options.twiceCountsDouble ? twiceUnits : 1
    }

    /// What a day marked so is worth.
    func units(of mark: HabitMark?, _ options: HabitOptions) -> Double {
        switch mark {
        case nil: 0
        case .partial: partialUnits
        case .done: 1
        case .twice: unitsPerDay(options)
        }
    }
}
