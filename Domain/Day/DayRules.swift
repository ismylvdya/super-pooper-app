import Foundation

/// Tunable numbers of the day logic (from `rules.json`).
struct DayRules: Codable, Hashable, Sendable {
    /// Used when `time_estimate` is empty.
    var defaultEstimateMinutes: Int
    /// Duration of a reminder block on the timeline.
    var reminderMinutes: Int
    /// Which planning levels are promoted to this week when the date falls in the current week.
    var autoPromoteFrom: [TaskStatus.Name]
    /// A link found by an event's title matches an event starting at most this far from the start it names.
    var eventLinkToleranceSeconds: Double
    /// The evening and overnight window for turning the day early, on the phone's clock.
    var earlyDayTurnFrom: LocalTime
    var earlyDayTurnUntil: LocalTime

    func earlyDayTurnTarget(in context: DayContext) -> LocalDate? {
        let time = LocalTime(context.now, in: context.calendar)
        let civilDay = LocalDate(context.now, in: context.calendar)
        guard time >= earlyDayTurnFrom || time < min(earlyDayTurnUntil, context.boundary) else { return nil }
        let target = time >= earlyDayTurnFrom ? civilDay.adding(days: 1) : civilDay
        return target == context.today.adding(days: 1) ? target : nil
    }

    func estimate(of task: TaskItem) -> Int {
        guard let minutes = task.timeEstimate, minutes > 0 else { return defaultEstimateMinutes }
        return minutes
    }

    /// How long a task's block lasts on the timeline: its estimate.
    func duration(of task: TaskItem) -> TimeInterval {
        TimeInterval(estimate(of: task) * 60)
    }

    /// How long a reminder's block lasts on the timeline.
    var reminderDuration: TimeInterval {
        TimeInterval(reminderMinutes * 60)
    }
}
