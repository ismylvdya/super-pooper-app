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
    case unmark
    case open
    case archive
    case delete
    case openInObsidian
    case restoreThisWeek
    case restoreHalfYear
    case restoreHabit
    /// An archived note back among the active ones: a task in Soon, a habit among the habits (its page's "…").
    case restoreFromArchive
    /// A done task back in Soon, reopened (from the done folder too).
    case returnFromDone
    /// A note in the trash back among the tasks.
    case restoreFromTrash
    case deleteEvent
    /// A notification's button: the same notification comes again later (Settings → Notifications);
    /// nothing about its item changes.
    case snooze
    /// An event alert's button: only the alert goes away; the event stays in Calendar and on the timeline.
    case dismissAlert
    /// A task begun: Started (a tag: it stays in its list).
    case start
    /// A started task back to plain This week.
    case notStarted
    /// The pool's Select mode, with this task picked first.
    case select
    /// High priority on the selected tasks (off when all of them have it already).
    case highPriority
    /// The selected tasks share one plate for the shown day (`DayWorm`); nothing is written to the notes.
    case worm
    /// The task, or the selected ones, leave their worm.
    case unworm
    /// A section of the shown day's pool, named by the user, takes the selected tasks.
    case newSection
    /// A task put off today (Not today) or a habit skipped today back in today's pool (`SetAsideToday`).
    case returnToToday
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
