import Foundation

/// One field edit of a task note. The data layer turns each into a single frontmatter key change.
/// List fields change by deltas (mark one day, add/remove/rename one link): the writer applies
/// them to the freshly read file, so entries added elsewhere meanwhile are never lost.
enum TaskFieldChange: Hashable, Sendable {
    case status(TaskStatus)
    case highPriority(Bool)
    case due(TaskDue?)
    case timeEstimate(Int?)
    case addPreviousTask(String)
    case removePreviousTask(String)
    case renamePreviousTask(from: String, to: String)
    /// Makes the note a subtask of another one (TaskNotes `projects`).
    case addProject(String)
    case renameProject(from: String, to: String)
    case subtaskOrder(Int?)
    case previousEvent(EventLink?)
    case nextEvent(EventLink?)
    case feel(TaskFeel)
    /// Rewrites fields of an older format into the current one, changing no value.
    case migrateLegacyFields
    /// Exactly one mark (or none) for `day` in the three instance lists.
    case markInstance(day: LocalDate, mark: HabitMark?)
    case completedDate(LocalDate?)
    /// The raw recurrence rule, or `nil` to remove it.
    case recurrence(String?)
    case reminderTimes([LocalTime])
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
