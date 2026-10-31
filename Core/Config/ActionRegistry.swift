import Foundation

enum HapticStyle: String, Codable, ConfigName {
    case none
    case light
    case medium
}

/// What a tap on screen feels like by what it does, outside the actions (which carry their own `haptic`); the style of
/// each is in `actions.json` → `haptics`.
enum HapticRole: String, ConfigName {
    /// A choice is picked or switched (a setting, a chip, a weekday, a link highlight).
    case select
    /// A habit day or a reminder is marked.
    case mark
    /// A dragged task lands on the timeline or in the pool.
    case drop
    /// Rows of a list change places (a subtask moved under another one too).
    case reorder
    /// A task goes to another list or day (+ to This week, back to today).
    case move
    /// A pull past its threshold, before letting go.
    case pullArmed
    /// A pull let go loads more.
    case extend
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
    /// A color token for the icon and title (Done is blue); menus otherwise use the label color.
    var color: String?
    let haptic: HapticStyle
    /// String Catalog keys of the confirmation dialog; `nil` = no confirmation.
    let confirmTitle: String?
    let confirmMessage: String?

    var needsConfirmation: Bool { confirmTitle != nil }
}

/// Every user action in one registry (`actions.json`): menus, swipes, notifications and widgets take titles, icons,
/// confirmation and haptics from here. The actions themselves are `ActionID`.
struct ActionRegistry: Decodable, Hashable, Sendable {
    let actions: [ActionDefinition]
    let menus: [String: [ActionID]]
    let haptics: TokenTable<HapticRole, HapticStyle>

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
        for action in actions {
            if let color = action.color, ColorToken(rawValue: color) == nil {
                throw ConfigError(file: file, path: "actions.\(action.id.rawValue).color", message: "unknown color token \"\(color)\"")
            }
        }
    }
}
