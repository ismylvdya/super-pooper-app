import Foundation

/// A status as the user reads it: a planning level's name, or a list of the user's own by its title.
enum StatusText {
    static func title(_ status: TaskStatus) -> String {
        switch status {
        case .thisWeek: L10n.string("status.thisWeek")
        case .halfYear: L10n.string("status.halfYear")
        case .someday: L10n.string("status.someday")
        case .done: L10n.string("status.done")
        case .archived: L10n.string("status.archived")
        case .habit: L10n.string("status.habit")
        }
    }
}
