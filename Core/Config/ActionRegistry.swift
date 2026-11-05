import Foundation

enum HapticStyle: String, Codable, ConfigName {
    case none
    case light
    case medium
    /// The tick of a picker wheel or a list row passing another while reordered.
    case selection
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
    /// A drop that cannot land.
    case dropRefused
    /// Rows of a list change places (a subtask moved under another one too).
    case reorder
    /// A task goes to another list or day (+ to Soon, back to today).
    case move
    /// A dragged row passes another row, or its landing spot on the timeline moves a drop step.
    case dragStep
    /// A pull past its threshold, before letting go.
    case pullArmed
    /// A pull let go loads more.
    case extend
    /// A long press set an alarm: a little stronger than a tap.
    case alarmSet
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
    /// A task of the done folder in the Done list.
    case filedTask
    case eventNotification
    /// A habit's day in the Habits list and in the history.
    case habitDay
    case reminderContext
    case eventContext
    /// The "…" menu on the page of a note that is in the trash.
    case trashedPage
    /// The bar of the pool's Select mode: the frequent actions are its buttons, the rarer ones its "…" menu.
    case selection

    /// The long-press menu of a task or a habit.
    static func context(of task: TaskItem) -> ActionMenu { task.isHabit ? .habitContext : .taskContext }

    /// The "…" menu on the page of a task or a habit.
    static func page(of task: TaskItem) -> ActionMenu { task.isHabit ? .habitPage : .taskPage }
}

/// The swipe buttons of a kind of list row (`actions.json` → `swipes`).
enum ActionSwipes: String, Codable, CaseIterable, Sendable {
    /// A task in a list (the Lists tab, the Done list, the search).
    case task
    /// A habit or a repeatable task in a list (Habits, Routines, the search).
    case habit
    /// A task or a habit in Soon.
    case review
    /// A task put off with Not today, at the bottom of Soon.
    case postponed
    case archivedTask
    case archivedHabit
    /// A note in the trash.
    case trash

    /// The row of a task or a habit in a list.
    static func row(of task: TaskItem) -> ActionSwipes { task.isHabit ? .habit : .task }
}

/// The swipe buttons of a row: `leading` show on a swipe to the right, `trailing` on a swipe to the left, each from the
/// edge in; the first one the row offers runs on a full swipe.
struct SwipeDefinition: Decodable, Hashable, Sendable {
    let leading: [ActionID]
    let trailing: [ActionID]

    private enum CodingKeys: String, CodingKey { case leading, trailing }

    init(leading: [ActionID], trailing: [ActionID]) {
        self.leading = leading
        self.trailing = trailing
    }

    init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leading = try container.decode([ActionID].self, forKey: .leading)
        trailing = try container.decode([ActionID].self, forKey: .trailing)
    }
}

/// One menu of `actions.json`: the frequent actions on top (`actions`), the rarer ones under a divider (`more`), each in
/// order, and whether it is about a habit's day.
struct MenuDefinition: Decodable, Hashable, Sendable {
    let frequent: [ActionID]
    let more: [ActionID]
    /// Its mark actions show the habit mark images (the habit's menus and notification buttons).
    let habitMarks: Bool

    /// Every action of the menu, the frequent ones first (a notification's buttons, which have no divider).
    var actions: [ActionID] { frequent + more }

    init(actions: [ActionID], more: [ActionID] = [], habitMarks: Bool = false) {
        frequent = actions
        self.more = more
        self.habitMarks = habitMarks
    }

    private enum CodingKeys: String, CodingKey { case actions, more, habitMarks }

    init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frequent = try container.decode([ActionID].self, forKey: .actions)
        more = try container.decodeIfPresent([ActionID].self, forKey: .more) ?? []
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
    /// A color token for the action's swipe button; none: a destructive action is the system's red, another the accent.
    var swipeTint: String?
    let haptic: HapticStyle
    /// String Catalog keys of the confirmation dialog; `nil` = no confirmation. The title is worded per kind of note:
    /// its key is this one and the kind (`confirm.delete.title.habit`).
    let confirmTitle: String?
    let confirmMessage: String?
    /// How many subtasks go along, under the message (a plural text); none = not said.
    var confirmSubtasks: String?
    /// How the action can be taken back from the banner; none = it cannot. An action that can be taken back happens at
    /// once, without its confirmation.
    var undo: UndoKind?

    var needsConfirmation: Bool { confirmTitle != nil }

    func confirmTitle(for kind: NoteKind) -> String? {
        confirmTitle.map { $0 + "." + kind.rawValue }
    }
}

/// How an action is taken back: by writing back the fields it changed (and the day's decisions), or out of the
/// store's trash (only where the store has one).
enum UndoKind: String, Codable, Hashable, Sendable {
    case edits
    case trash
}

/// Every user action in one registry (`actions.json`): menus, swipes, notifications and widgets take titles, icons,
/// confirmation and haptics from here. The actions themselves are `ActionID`.
struct ActionRegistry: Decodable, Hashable, Sendable {
    let actions: [ActionDefinition]
    /// Every menu is there, and no other (checked as the file is read).
    let menus: TokenTable<ActionMenu, MenuDefinition>
    /// Every kind of row's swipes, and no other.
    let swipes: TokenTable<ActionSwipes, SwipeDefinition>
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
            for (key, token) in [("color", action.color), ("swipeTint", action.swipeTint)] {
                if let token, ColorToken(rawValue: token) == nil {
                    throw ConfigError(file: file, path: "actions.\(action.id.rawValue).\(key)", message: "unknown color token \"\(token)\"")
                }
            }
        }
    }
}
