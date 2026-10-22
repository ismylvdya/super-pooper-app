import Foundation

/// Tunable numbers of the day logic (from `rules.json`).
struct DayRules: Codable, Hashable, Sendable {
    /// Used when `time_estimate` is empty.
    var defaultEstimateMinutes: Int
    /// Duration of a reminder block on the timeline.
    var reminderMinutes: Int
    /// Which statuses are promoted to `this_week` when `due` falls in the current week.
    var autoPromoteFrom: [String]

    func estimate(of task: TaskNote) -> Int {
        guard let minutes = task.timeEstimate, minutes > 0 else { return defaultEstimateMinutes }
        return minutes
    }
}
