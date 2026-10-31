import Foundation

/// Everything the user can do to an item from a menu, a swipe, a notification or a widget. How each looks and which
/// menus list it is `actions.json`; which of them an item offers now is `ActionAvailability`.
enum ActionID: String, Codable, CaseIterable, Sendable {
    case done
    case partial
    case twice
    case skipToday
    case notToday
    case unmark
    case open
    case archive
    case delete
    case openInObsidian
    case restoreThisWeek
    case restoreHalfYear
    case restoreHabit
    case deleteEvent
}

extension ActionID {
    /// The habit mark a menu or notification action sets (`nil`: Unmark, and the actions that set no mark).
    var habitMark: HabitMark? {
        switch self {
        case .done: .done
        case .partial: .partial
        case .twice: .twice
        default: nil
        }
    }
}
