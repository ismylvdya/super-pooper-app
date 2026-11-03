import Foundation

/// A list whose page stands left of the pool on Tasks (`lists.json` → `backlog`): its title, its icon (shown by the
/// sideways pull that opens it) and the one planning level it holds.
struct BacklogList: Hashable, Sendable, Identifiable {
    let id: String
    /// Text key in `Localizable.xcstrings`.
    let title: String
    let icon: Icon
    let status: TaskStatus
}

extension TaskListsConfig {
    /// The backlog pages, nearest to the pool first (checked at loading: each names a list of one level).
    var backlogLists: [BacklogList] {
        backlog.compactMap { id in
            guard let list = list(id), let status = list.statuses?.first?.status else { return nil }
            return BacklogList(id: id, title: list.title, icon: list.icon, status: status)
        }
    }

    func backlogList(_ id: String) -> BacklogList? {
        backlogLists.first { $0.id == id }
    }
}
