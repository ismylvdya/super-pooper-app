import Foundation

/// Everything the user can do to an item from a menu, a swipe, a notification or a widget. How each looks and which
/// menus list it is `actions.json`; which of them an item offers now is `ActionAvailability`.
enum ActionID: String, Codable, CaseIterable, Sendable {
    case done
    case partial
    case twice
    case skipToday
    case notToday
    /// A task put off with Not today back in today.
    case backToToday
    case unmark
    case open
    case archive
    case delete
    case openInObsidian
    case restoreThisWeek
    case restoreHalfYear
    case restoreHabit
    /// A done task back in Soon, reopened (from the done folder too).
    case returnFromDone
    /// A note in the trash back among the tasks.
    case restoreFromTrash
    case deleteEvent
    /// A notification's button: the same notification comes again later (`rules.json` → `notifications.snoozeMinutes`);
    /// nothing about its item changes.
    case snooze
}

extension ActionID {
    /// Done, Partially, Twice and Unmark: the actions that set a habit's mark for a day (Unmark: none).
    var setsHabitMark: Bool {
        switch self {
        case .done, .partial, .twice, .unmark: true
        default: false
        }
    }

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
