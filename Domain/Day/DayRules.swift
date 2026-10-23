import Foundation

/// Tunable numbers of the day logic (from `rules.json`).
struct DayRules: Codable, Hashable, Sendable {
    /// Used when `time_estimate` is empty.
    var defaultEstimateMinutes: Int
    /// Duration of a reminder block on the timeline.
    var reminderMinutes: Int
    /// Which statuses are promoted to `this_week` when `due` falls in the current week.
    var autoPromoteFrom: [String]
    /// Parts of the day for habits' time of day: morning until `morningEnds`, evening from `eveningStarts`.
    var morningEnds: LocalTime
    var eveningStarts: LocalTime

    func estimate(of task: TaskNote) -> Int {
        guard let minutes = task.timeEstimate, minutes > 0 else { return defaultEstimateMinutes }
        return minutes
    }

    /// Hours after midnight (before the day boundary) still belong to the evening.
    func partOfDay(_ context: DayContext) -> HabitTimeOfDay {
        let time = LocalTime(minutesSinceMidnight: context.calendar.component(.hour, from: context.now) * 60
                             + context.calendar.component(.minute, from: context.now))
        if time < context.boundary || time >= eveningStarts { return .evening }
        return time < morningEnds ? .morning : .day
    }
}
