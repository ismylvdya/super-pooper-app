import Foundation

/// Every user action in one registry (`actions.json`): menus, swipes, notifications
/// and widgets take titles, icons, confirmation and haptics from here.
enum ActionID: String, Codable, CaseIterable, Sendable {
    case done
    case partial
    case twice
    case skipToday
    case unmark
    case open
    case archive
    case delete
    case openInObsidian
    case restoreThisWeek
    case restoreHalfYear
    case restoreHabit
    case routines
    case deleteEvent
}

enum HapticStyle: String, Codable, Sendable {
    case none
    case light
    case medium
}

enum ActionMenu: String, Codable, CaseIterable, Sendable {
    case habitContext
    case taskContext
    case taskPage
    case habitNotification
    case taskNotification
    case reminderNotification
    case archiveRow
    case habitPage
    case habitArchiveRow
    case eventNotification
    /// A habit's day in the Habits list and in the history.
    case habitDay
    case reminderContext
    case eventContext
}

extension ActionMenu {
    /// Menus about a habit's day: their mark actions use the habit mark images.
    var isHabitMenu: Bool { self == .habitContext || self == .habitNotification || self == .habitDay }
}

struct ActionDefinition: Codable, Hashable, Sendable {
    let id: ActionID
    /// String Catalog key.
    let title: String
    /// SF Symbol name.
    let icon: String
    let destructive: Bool
    let haptic: HapticStyle
    /// String Catalog keys of the confirmation dialog; `nil` = no confirmation.
    let confirmTitle: String?
    let confirmMessage: String?

    var needsConfirmation: Bool { confirmTitle != nil }
}

struct ActionRegistry: Codable, Hashable, Sendable {
    let actions: [ActionDefinition]
    let menus: [String: [ActionID]]

    func definition(_ id: ActionID) -> ActionDefinition {
        actions.first { $0.id == id } ?? ActionDefinition(id: id, title: id.rawValue, icon: "questionmark",
                                                          destructive: false, haptic: .none,
                                                          confirmTitle: nil, confirmMessage: nil)
    }

    func actions(in menu: ActionMenu) -> [ActionDefinition] {
        (menus[menu.rawValue] ?? []).map(definition)
    }

    /// Every action needs a definition and every menu must be present.
    func validate(file: String) throws {
        for id in ActionID.allCases where !actions.contains(where: { $0.id == id }) {
            throw ConfigError(file: file, path: "actions", message: "no definition for action \"\(id.rawValue)\"")
        }
        for menu in ActionMenu.allCases where menus[menu.rawValue] == nil {
            throw ConfigError(file: file, path: "menus", message: "missing menu \"\(menu.rawValue)\"")
        }
    }
}
