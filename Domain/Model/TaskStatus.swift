import Foundation

/// Task level in the weekly planning flow. How a store writes each one is the store's business.
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

    /// A level as configs name it (`lists.json`, `rules.json`): a name that is not one of these stops the app with a
    /// config error, instead of quietly matching nothing.
    enum Name: String, Codable, Hashable, Sendable {
        case thisWeek, halfYear, someday, waiting, done, archived

        var status: TaskStatus {
            switch self {
            case .thisWeek: .thisWeek
            case .halfYear: .halfYear
            case .someday: .someday
            case .waiting: .waiting
            case .done: .done
            case .archived: .archived
            }
        }
    }
}
