import Foundation

/// Task level in the weekly planning flow. Raw TaskNotes values live in `FieldMapping`.
enum TaskStatus: Hashable, Codable, Sendable {
    case thisWeek
    case halfYear
    case someday
    case waiting
    case done
    case archived
    /// Habits carry a recurrence instead of a planning level; they are always active.
    case habit
    case other(String)

    /// The planning levels of open tasks.
    static let open: [TaskStatus] = [.thisWeek, .halfYear, .someday, .waiting]
    static let known: [TaskStatus] = open + [.done, .archived]
    /// Where the review moves a task: a planning level or the archive (done is a check-off, not a move).
    static let reviewChoices: [TaskStatus] = open + [.archived]

    var isCompleted: Bool { self == .done || self == .archived }
}
