import Foundation

/// One TaskNotes note as the app understands it. The note body is not part of the model;
/// it is loaded on demand by the task repository.
struct TaskNote: Identifiable, Hashable, Codable, Sendable {
    /// File name without `.md`; TaskNotes stores the title in the file name.
    var name: String
    /// Path relative to the vault root, e.g. `TaskNotes/Tasks/Name.md`.
    var relativePath: String
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
    /// The note still has fields of an older format (separate setting keys, `need_energy`/`pleasant`); the next
    /// sync rewrites them.
    var hasLegacyFields = false
    var recurrenceRaw: String?
    var recurrence: RecurrenceRule?
    var completeInstances: [LocalDate] = []
    var partialInstances: [LocalDate] = []
    var twiceInstances: [LocalDate] = []
    /// Habit reminders, several per day (`reminder_times`, `HH:mm`).
    var reminderTimes: [LocalTime] = []
    /// The zone the due time and reminder times are kept in (IANA name); nil = wall-clock times (`ZonedTimes`).
    var timeZone: String?
    var habit = HabitOptions()
    var completedDate: LocalDate?
    var dateCreated: Date?
    var dateModified: Date?
    var problems: [TaskProblem] = []

    var id: String { name }
    /// A habit is marked by `status: habit`; a note that only has a recurrence is read as one too.
    var isHabit: Bool { status == .habit || recurrenceRaw != nil }
    var isArchived: Bool { status == .archived }
    /// Habits that are not archived, and only those switched on for Today, take part in the day.
    var isInTodayHabits: Bool { isHabit && !isArchived && habit.showInToday }
    /// Times of day a habit is planned at: its reminders, or the time of an older-style `due`.
    var habitTimes: [LocalTime] {
        if !reminderTimes.isEmpty { return reminderTimes }
        return due?.time.map { [$0] } ?? []
    }
    /// A habit done twice a day: the Twice option, or two or more reminders a day (the second Done is Twice).
    var isTwiceADay: Bool { habit.twiceADay || habitTimes.count >= 2 }
}

/// A data issue found in a single note (shown as a badge, never as a push).
enum TaskProblem: Hashable, Codable, Sendable {
    case unknownRecurrence(String)
    case invalidField(key: String, value: String)
    case linkedTaskNotFound(String)
    case eventNotFound(String)
    case dependencyCycle
}
