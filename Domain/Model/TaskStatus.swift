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

    static let known: [TaskStatus] = [.thisWeek, .halfYear, .someday, .waiting, .done, .archived]

    var isCompleted: Bool { self == .done || self == .archived }
}
