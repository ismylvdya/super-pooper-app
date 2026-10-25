import Foundation

/// The lists of the Lists tab (`lists.json`): each a filter over all task notes.
struct TaskListsConfig: Codable, Hashable, Sendable {
    struct List: Codable, Hashable, Sendable, Identifiable {
        let id: String
        /// Text key in `Localizable.xcstrings`.
        let title: String
        /// A key of `icons.json`.
        let icon: Icon
        /// Planning levels in the list; none = every open one (this week, half a year, someday, waiting).
        var statuses: [ListStatus]?
        var pleasant: Bool?
        var needEnergy: Bool?
        /// Only tasks estimated at most this many minutes (the default estimate counts).
        var maxEstimate: Int?
    }

    /// Planning levels by their names in `field-mapping.json` → `statuses`.
    enum ListStatus: String, Codable, Hashable, Sendable {
        case thisWeek, halfYear, someday, waiting, done

        var status: TaskStatus {
            switch self {
            case .thisWeek: .thisWeek
            case .halfYear: .halfYear
            case .someday: .someday
            case .waiting: .waiting
            case .done: .done
            }
        }
    }

    let lists: [List]

    func list(_ id: String) -> List? { lists.first { $0.id == id } }
}

extension TaskListsConfig.List {
    var filter: TaskListFilter {
        TaskListFilter(statuses: statuses?.map(\.status) ?? TaskListFilter.openStatuses, pleasant: pleasant,
                       needEnergy: needEnergy, maxEstimate: maxEstimate)
    }
}
