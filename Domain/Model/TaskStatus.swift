import Foundation

/// Task level in the weekly planning flow. How a store writes each one is the store's business.
enum TaskStatus: Hashable, Codable, Sendable {
    /// Captured and not planned yet (the New Task intent writes here); never in a day.
    case inbox
    case thisWeek
    /// Started (half done): this week's task the user has begun. It counts as this week everywhere (`planningLevel`).
    case inProgress
    case halfYear
    case someday
    case waiting
    case done
    case archived
    /// Habits carry a recurrence instead of a planning level; they are always active.
    case habit
    case other(String)

    /// The planning levels of open tasks.
    static let open: [TaskStatus] = [.inbox, .thisWeek, .halfYear, .someday, .waiting]
    /// Every status a task's page offers: the planning levels, Started next to This week, done and archived.
    static let known: [TaskStatus] = [.inbox, .thisWeek, .inProgress, .halfYear, .someday, .waiting, .done, .archived]
    /// Where the review moves a task: a planning level or the archive (done is a check-off, not a move). Nothing goes
    /// back into the Inbox.
    static let reviewChoices: [TaskStatus] = open.filter { $0 != .inbox } + [.archived]

    var isCompleted: Bool { self == .done || self == .archived }

    /// The planning level the status stands for: a started task is this week's.
    var planningLevel: TaskStatus { self == .inProgress ? .thisWeek : self }
    var isThisWeek: Bool { planningLevel == .thisWeek }
    var isStarted: Bool { self == .inProgress }

    /// A level as configs name it (`lists.json`, `rules.json`): a name that is not one of these stops the app with a
    /// config error, instead of quietly matching nothing.
    enum Name: String, Codable, Hashable, Sendable {
        case inbox, thisWeek, halfYear, someday, waiting, done, archived

        var status: TaskStatus {
            switch self {
            case .inbox: .inbox
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
