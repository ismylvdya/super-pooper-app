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

/// One menu of `actions.json`: its actions in order, and whether it is about a habit's day.
struct MenuDefinition: Decodable, Hashable, Sendable {
    let actions: [ActionID]
    /// Its mark actions show the habit mark images (the habit's menus and notification buttons).
    let habitMarks: Bool

    init(actions: [ActionID], habitMarks: Bool = false) {
        self.actions = actions
        self.habitMarks = habitMarks
    }

    private enum CodingKeys: String, CodingKey { case actions, habitMarks }

    init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        actions = try container.decode([ActionID].self, forKey: .actions)
        habitMarks = try container.decodeIfPresent(Bool.self, forKey: .habitMarks) ?? false
    }
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
    /// Every menu is there, and no other (checked as the file is read).
    let menus: TokenTable<ActionMenu, MenuDefinition>
    let haptics: TokenTable<HapticRole, HapticStyle>

    /// The definition of an action; `validate` made sure every action has one.
    func definition(_ id: ActionID) -> ActionDefinition {
        guard let definition = actions.first(where: { $0.id == id }) else {
            preconditionFailure("actions.json was validated: no definition for \(id.rawValue)")
        }
        return definition
    }

    func actions(in menu: ActionMenu) -> [ActionDefinition] {
        menus[menu].actions.map(definition)
    }

    /// Every action needs a definition.
    func validate(file: String) throws {
        for id in ActionID.allCases where !actions.contains(where: { $0.id == id }) {
            throw ConfigError(file: file, path: "actions", message: "no definition for action \"\(id.rawValue)\"")
        }
        for action in actions {
            if let color = action.color, ColorToken(rawValue: color) == nil {
                throw ConfigError(file: file, path: "actions.\(action.id.rawValue).color", message: "unknown color token \"\(color)\"")
            }
        }
    }
}
