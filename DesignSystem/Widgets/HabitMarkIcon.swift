import SwiftUI

/// The habit marks as template images from the asset catalog (they take the menu's text color). The same
/// images are the icons of the habit notification buttons.
enum HabitMarkIcon {
    static func icon(for mark: HabitMark?) -> Icon {
        switch mark {
        case nil: .habitMarkOpen
        case .done: .habitMarkDone
        case .partial: .habitMarkPartial
        case .twice: .habitMarkTwice
        }
    }

    /// The habit mark an action sets, if it sets one (Unmark: the open mark).
    static func icon(for action: ActionID) -> Icon? {
        action.setsHabitMark ? icon(for: action.habitMark) : nil
    }
}
