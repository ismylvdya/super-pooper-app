import Foundation

/// One edit of a task or habit, in the domain's terms; the store turns it into its own fields. List fields change by
/// deltas (mark one day, add or remove one link): the store applies them to the latest stored version, so entries added
/// elsewhere meanwhile are never lost.
enum TaskEdit: Hashable, Sendable {
    /// Moves the item to a planning level or the archive. A task that was done is no longer done (its day of completion
    /// goes). Entering done is `complete(on:)`: every status change is decided by `TaskMarking.changes(setting:on:)`.
    case status(TaskStatus)
    /// The task is done on `day`.
    case complete(on: LocalDate)
    /// A done task is open again, in this week.
    case reopen
    case highPriority(Bool)
    case due(TaskDue?)
    case timeEstimate(Int?)
    case addPreviousTask(String)
    case removePreviousTask(String)
    /// Makes the item a subtask of another one.
    case addProject(String)
    case subtaskOrder(Int?)
    case previousEvent(EventLink?)
    case nextEvent(EventLink?)
    case feel(TaskFeel)
    /// Exactly one mark (or none) for `day` in the three instance lists.
    case markInstance(day: LocalDate, mark: HabitMark?)
    /// The raw recurrence rule, or `nil` to remove it.
    case recurrence(String?)
    case reminderTimes([LocalTime])
    /// The zone of the item's times; nil = wall-clock times.
    case timeZone(String?)
    case habitColor(String?)
    case harmful(Bool)
    case repeatable(Bool)
    case showInToday(Bool)
    case timeOfDay(HabitTimeOfDay?)
    case twiceADay(Bool)
    case twiceCountsDouble(Bool)
    case weeklyGoal(Int?)
    case allowedSkips(Int?)
}
