import Foundation

/// A kind of element that can take the accent color the user picked.
enum AccentCategory: String, CaseIterable, Sendable {
    case selects, toolbars, calendar, switches, icons, checkmarks, buttons, swipes, dragMarks
}
