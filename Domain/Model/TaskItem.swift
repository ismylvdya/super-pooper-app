import Foundation

/// A task or habit as the app understands it, whatever format its store keeps it in. Its text is not part of the
/// model; the store reads it on demand.
struct TaskItem: Identifiable, Hashable, Codable, Sendable {
    /// Where the store keeps it; nothing outside the store looks inside.
    var id: TaskID
    /// The title, and the name other items refer to it by (TaskNotes: the file name without `.md`).
    var name: String
    var status: TaskStatus
    var isHighPriority: Bool = false
    var due: TaskDue?
    var timeEstimate: Int?
    /// Names of the items this one is a subtask of.
    var projects: [String] = []
    /// Its place among the parent's subtasks, once they were put in order; nil = after those, by name.
    var subtaskOrder: Int?
    var feel: TaskFeel = .neutral
    var recurrence: RecurrenceRule?
    /// The item repeats by a rule the app cannot read (a problem on it): it never comes up in a day, yet it is a habit.
    var hasUnreadableRecurrence = false
    /// A recurring task's mark of each day it was marked on.
    var marks: [LocalDate: HabitMark] = [:]
    /// Habit reminders, several per day (`reminder_times`, `HH:mm`).
    var reminderTimes: [LocalTime] = []
    /// The times that ring as alarms.
    var alarms: [TimeAlarm] = []
    /// The zone the due time and reminder times are kept in (IANA name); nil = wall-clock times (`ZonedTimes`).
    var timeZone: String?
    var habit = HabitOptions()
    var completedDate: LocalDate?
    var dateCreated: Date?
    /// `date_created` on the clock it was written by (no zone): where a habit's days and history start.
    var created: TaskDue?
    var dateModified: Date?
    var problems: [TaskProblem] = []
    /// Its day passed with it not done, and it was carried into today's pool without a time (`docs/BACKEND.md`).
    var isOverdue = false
    /// Undated in Next actions: not among today's tasks. Only a date brings a task into a day.
    var waitsInList = false
    /// Its place among the store's lines; a list keeps that order. Nil = by name, after those.
    var storeOrder: Int?

    /// A habit has the habit status or repeats by a rule (even one that cannot be read).
    var isHabit: Bool { status == .habit || recurrence != nil || hasUnreadableRecurrence }
    var isArchived: Bool { status == .archived }
    /// Where an archived note goes back to: a task to Soon, a habit among the habits.
    var statusOutOfArchive: TaskStatus { isHabit ? .habit : .thisWeek }
    /// A task of a later planning level (or done, or archived) can be brought to this week.
    var canPromote: Bool { !isHabit && !status.isThisWeek }
    /// Habits that are not archived, and only those switched on for Today, take part in the day.
    var isInTodayHabits: Bool { isHabit && !isArchived && habit.showInToday }
    /// Times of day a habit is planned at: its reminders, or the time of an older-style `due`.
    var habitTimes: [LocalTime] {
        // Carried over from a day it missed: today it has no times of its own.
        if isOverdue { return [] }
        if !reminderTimes.isEmpty { return reminderTimes }
        return due?.time.map { [$0] } ?? []
    }
    func mark(on day: LocalDate) -> HabitMark? { marks[day] }
    /// Done as of `day`: a task done at all, a habit (a repeatable subtask too) marked so that day is closed.
    func isDone(on day: LocalDate) -> Bool {
        isHabit ? HabitMarking.isDayClosed(mark(on: day), twiceADay: isTwiceADay) : status.isCompleted
    }

    /// A habit done twice a day: the Twice option, or two or more reminders a day (the second Done is Twice).
    var isTwiceADay: Bool { habit.twiceADay || reminderTimes.count >= 2 }
}

/// A data issue found in a single note (shown as a badge, never as a push).
enum TaskProblem: Hashable, Codable, Sendable {
    case unknownRecurrence(String)
    /// A repeat with no start in the note (no DTSTART, `due` or `date_created`): its days are counted from a fixed day.
    case recurrenceWithoutStart
    /// A value the store could not read (as written there).
    case invalidValue(field: TaskField, value: String)
}
