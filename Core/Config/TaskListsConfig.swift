import Foundation

/// The lists of the Lists tab (`lists.json`) in their groups: each a filter over all task notes.
struct TaskListsConfig: Codable, Hashable, Sendable {
    /// A plate of the Lists tab with a title over it.
    struct Group: Codable, Hashable, Sendable, Identifiable {
        let id: String
        /// Text key in `Localizable.xcstrings`.
        let title: String
        let lists: [List]
    }

    struct List: Codable, Hashable, Sendable, Identifiable {
        let id: String
        /// Text key in `Localizable.xcstrings`.
        let title: String
        /// A key of `icons.json`.
        let icon: Icon
        /// Planning levels in the list; none = every open one (this week, half a year, someday, waiting). With several
        /// the list is split by level.
        var statuses: [TaskStatus.Name]?
        var feel: TaskFeel?
        /// Only tasks estimated at most this many minutes (the default estimate counts).
        var maxEstimate: Int?
    }

    /// A glyph the Lists icon can be (Settings → Lists): the icon wherever the button to the lists stands.
    struct IconChoice: Codable, Hashable, Sendable, Identifiable {
        /// What the settings keep (`AppSettings.Lists.icon`).
        let id: String
        /// Text key in `Localizable.xcstrings`.
        let title: String
        /// A key of `icons.json`.
        let icon: Icon
    }

    let groups: [Group]
    let icons: [IconChoice]

    var lists: [List] { groups.flatMap(\.lists) }

    func list(_ id: String) -> List? { lists.first { $0.id == id } }

    /// There is a Lists icon to pick, and the default one is among them.
    func validate(defaultIcon: String, file: String) throws {
        if !icons.contains(where: { $0.id == defaultIcon }) {
            throw ConfigError(file: file, path: "icons", message: "no Lists icon \"\(defaultIcon)\" (the default in defaults.json)")
        }
    }

    /// The Lists icon picked in the settings; an id no choice has any more (an older settings file) gets the first one.
    func icon(for choiceID: String) -> Icon {
        (icons.first { $0.id == choiceID } ?? icons[0]).icon
    }
}

extension TaskListsConfig.List {
    var filter: TaskListFilter {
        TaskListFilter(statuses: statuses?.map(\.status) ?? TaskStatus.open, feel: feel,
                       maxEstimate: maxEstimate)
    }
}
