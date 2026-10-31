import Foundation

/// One TaskNotes note as the app understands it. The note body is not part of the model;
/// it is loaded on demand by the task repository.
struct TaskNote: Identifiable, Hashable, Codable, Sendable {
    /// Where the store keeps it; nothing outside the store looks inside.
    var id: TaskID
    /// The title, and the name other items refer to it by (TaskNotes: the file name without `.md`).
    var name: String
    var status: TaskStatus
    var isHighPriority: Bool = false
    var due: TaskDue?
    var timeEstimate: Int?
    /// Names of the tasks that come before this one (`previous_task`, TaskNotes "blocked by").
    var previousTasks: [String] = []
    /// Names of the notes this one is a subtask of (`projects`, TaskNotes "subtask of").
    var projects: [String] = []
    /// Its place among the parent's subtasks, once they were put in order; nil = after those, by name.
    var subtaskOrder: Int?
    var previousEvent: EventLink?
    var nextEvent: EventLink?
    var feel: TaskFeel = .neutral
    var recurrence: RecurrenceRule?
    /// The item repeats by a rule the app cannot read (a problem on it): it never comes up in a day, yet it is a habit.
    var hasUnreadableRecurrence = false
    /// A recurring task's mark of each day it was marked on.
    var marks: [LocalDate: HabitMark] = [:]
    /// Habit reminders, several per day (`reminder_times`, `HH:mm`).
    var reminderTimes: [LocalTime] = []
    /// The zone the due time and reminder times are kept in (IANA name); nil = wall-clock times (`ZonedTimes`).
    var timeZone: String?
    var habit = HabitOptions()
    var completedDate: LocalDate?
    var dateCreated: Date?
    /// `date_created` on the clock it was written by (no zone): where a habit's days and history start.
    var created: TaskDue?
    var dateModified: Date?
    var problems: [TaskProblem] = []

    /// A habit has the habit status or repeats by a rule (even one that cannot be read).
    var isHabit: Bool { status == .habit || recurrence != nil || hasUnreadableRecurrence }
    var isArchived: Bool { status == .archived }
    /// A task of a later planning level (or done, or archived) can be brought to this week.
    var canPromote: Bool { !isHabit && status != .thisWeek }
    /// Another task can be linked to it (before or after it); archived notes are out of the way.
    var isLinkable: Bool { !isArchived }
    /// Habits that are not archived, and only those switched on for Today, take part in the day.
    var isInTodayHabits: Bool { isHabit && !isArchived && habit.showInToday }
    /// Times of day a habit is planned at: its reminders, or the time of an older-style `due`.
    var habitTimes: [LocalTime] {
        if !reminderTimes.isEmpty { return reminderTimes }
        return due?.time.map { [$0] } ?? []
    }
    func mark(on day: LocalDate) -> HabitMark? { marks[day] }

    /// A habit done twice a day: the Twice option, or two or more reminders a day (the second Done is Twice).
    var isTwiceADay: Bool { habit.twiceADay || habitTimes.count >= 2 }
}

/// A data issue found in a single note (shown as a badge, never as a push).
enum TaskProblem: Hashable, Codable, Sendable {
    case unknownRecurrence(String)
    /// A repeat with no start in the note (no DTSTART, `due` or `date_created`): its days are counted from a fixed day.
    case recurrenceWithoutStart
    case invalidField(key: String, value: String)
    case linkedTaskNotFound(String)
    case eventNotFound(String)
    case dependencyCycle
}
