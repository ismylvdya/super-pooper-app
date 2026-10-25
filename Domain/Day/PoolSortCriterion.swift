import Foundation

/// Pool ordering criteria, compared one after another (order comes from `sort.json`).
enum PoolSortCriterion: String, Codable, CaseIterable, Sendable {
    /// The morning routine (habits of the morning) goes above everything.
    case morningRoutine
    /// Recurring tasks without a time go first.
    case habitsFirst
    /// Habits of the current part of the day go up, habits of another part go down.
    case habitTimeOfDay
    /// Within the morning and evening routines, the user's routine order.
    case routineOrder
    /// `due` today (with or without time) beats everything below.
    case dueToday
    case highPriority
    /// The nearest `due` within this week goes earlier.
    case nearestDueThisWeek
    /// `need_energy` tasks go up before the energy hour and down after it.
    case energyBeforeEnergyHour
    /// `pleasant: false` before the rest.
    case unpleasantFirst
    /// Shorter `time_estimate` first.
    case shortFirst
    /// Older `date_created` first.
    case olderFirst
}
