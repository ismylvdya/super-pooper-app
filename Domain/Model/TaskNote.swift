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
    var previousEvent: EventLink?
    var nextEvent: EventLink?
    var needEnergy: Bool = false
    /// `nil` when the field is absent.
    var pleasant: Bool?
    var recurrenceRaw: String?
    var recurrence: RecurrenceRule?
    var completeInstances: [LocalDate] = []
    var partialInstances: [LocalDate] = []
    var twiceInstances: [LocalDate] = []
    var completedDate: LocalDate?
    var dateCreated: Date?
    var dateModified: Date?
    var problems: [TaskProblem] = []

    var id: String { name }
    var isRecurring: Bool { recurrenceRaw != nil }
}

/// A data issue found in a single note (shown as a badge, never as a push).
enum TaskProblem: Hashable, Codable, Sendable {
    case unknownRecurrence(String)
    case invalidField(key: String, value: String)
    case linkedTaskNotFound(String)
    case eventNotFound(String)
    case dependencyCycle
}
