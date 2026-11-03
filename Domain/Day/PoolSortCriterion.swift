import Foundation

/// Pool ordering criteria, compared one after another (order comes from `sort.json`).
enum PoolSortCriterion: String, Codable, CaseIterable, Sendable {
    /// Habits without a time of day (no reminder) go first.
    case habitsFirst
    /// Within each routine (morning, evening), the user's order of it (Habits → Routines).
    case routineOrder
    /// `due` today (with or without time) beats everything below.
    case dueToday
    case highPriority
    /// The nearest `due` within this week goes earlier.
    case nearestDueThisWeek
    /// Tasks that need energy (`feel: need_energy`) go up before the energy hour and down after it.
    case energyBeforeEnergyHour
    /// Pleasant tasks (`feel: pleasant`) after the rest: they are a reward.
    case unpleasantFirst
    /// Shorter `time_estimate` first.
    case shortFirst
    /// Older `date_created` first.
    case olderFirst
}
