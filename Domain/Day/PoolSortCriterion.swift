import Foundation

/// Pool ordering criteria, compared one after another (order comes from `sort.json`).
enum PoolSortCriterion: String, Codable, CaseIterable, Sendable {
    /// The morning routine (habits of the morning) goes above everything.
    case morningRoutine
    /// Habits without a time of day (no reminder) go first.
    case habitsFirst
    /// Habits of the current part of the day go up, habits of another part go down.
    case habitTimeOfDay
    /// Within each routine (morning, day, evening), the user's order of it (Habits → Routines).
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
