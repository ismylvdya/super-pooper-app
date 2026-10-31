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

    let groups: [Group]

    var lists: [List] { groups.flatMap(\.lists) }

    func list(_ id: String) -> List? { lists.first { $0.id == id } }
}

extension TaskListsConfig.List {
    var filter: TaskListFilter {
        TaskListFilter(statuses: statuses?.map(\.status) ?? TaskStatus.open, feel: feel,
                       maxEstimate: maxEstimate)
    }
}
