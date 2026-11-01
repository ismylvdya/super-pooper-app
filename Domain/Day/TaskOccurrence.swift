import Foundation

/// Answers "does this recurring task have an instance on that day", the way TaskNotes does.
struct TaskOccurrence: Sendable {
    /// Where the days of a rule are counted from when the note says nothing (no DTSTART, `due` or `date_created`): one
    /// fixed day, so the rule keeps its own days instead of matching whatever day is asked about. Such a note gets the
    /// problem `recurrenceWithoutStart`.
    static let undatedStart = LocalDate(dayNumber: 0)

    let days: DayBoundary

    func occurs(_ task: TaskItem, on day: LocalDate) -> Bool {
        schedule(of: task).occurs(on: day)
    }

    /// Build it once per task and ask it about many days: a COUNT rule lists its days up front.
    func schedule(of task: TaskItem) -> TaskSchedule {
        guard task.isHabit else { return TaskSchedule(isRecurring: false, recurrence: nil) }
        let recurrence = task.recurrence.map { RecurrenceSchedule(rule: $0, fallbackStart: start(of: task) ?? Self.undatedStart) }
        return TaskSchedule(isRecurring: true, recurrence: recurrence)
    }

    /// The first day of the rule: DTSTART, else the `due` day, else the day the note was created (as written, not moved
    /// through the phone's zone); nil when the note has none of them.
    func start(of task: TaskItem) -> LocalDate? {
        task.recurrence?.startDate ?? task.due?.day ?? task.created.map(days.day(of:))
    }

    /// A rule with nothing in the note to start its days from.
    func hasNoStart(_ task: TaskItem) -> Bool {
        task.isHabit && task.recurrence != nil && start(of: task) == nil
    }
}

/// The days of one task. Unknown rules count as "every day" (TaskNotes shows such tasks everywhere too); the problem
/// badge comes from the parser.
struct TaskSchedule: Sendable {
    let isRecurring: Bool
    let recurrence: RecurrenceSchedule?

    func occurs(on day: LocalDate) -> Bool {
        guard isRecurring else { return false }
        return recurrence?.occurs(on: day) ?? true
    }
}
