import Foundation

/// This week's list as three groups to drag tasks between: Morning, the rest of the day and Evening. One flat
/// list with a header row per group, so a row can be dragged across groups; its group is the header above it.
enum ReviewGroups {
    enum Group: String, CaseIterable, Hashable, Sendable {
        case morning, day, evening

        init(_ part: HabitTimeOfDay?) {
            switch part {
            case .morning: self = .morning
            case .evening: self = .evening
            case .day, nil: self = .day
            }
        }

        /// What `time_of_day` the group writes: none for the day.
        var timeOfDay: HabitTimeOfDay? {
            switch self {
            case .morning: .morning
            case .day: nil
            case .evening: .evening
            }
        }
    }

    enum Row: Hashable, Identifiable, Sendable {
        case header(Group)
        case item(String)

        var id: String {
            switch self {
            case .header(let group): "header:\(group.rawValue)"
            case .item(let name): name
            }
        }
    }

    /// The rows: each group's header, then its items in pool order.
    static func rows(_ pool: [DayItem]) -> [Row] {
        Group.allCases.flatMap { group in
            [.header(group)] + pool.filter { Group($0.task.habit.timeOfDay) == group }.map { .item($0.id) }
        }
    }

    struct Move: Equatable, Sendable {
        /// The new order of all tasks.
        let order: [String]
        /// The tasks whose group changed, with their new group.
        let regrouped: [String: Group]
    }

    /// A drag in the flat rows; headers stay where they are (a row cannot go above the first header).
    static func move(_ rows: [Row], from source: IndexSet, to destination: Int, pool: [DayItem]) -> Move {
        var moved = rows
        moved.move(fromOffsets: source, toOffset: max(destination, 1))
        var group = Group.morning
        var order: [String] = []
        var regrouped: [String: Group] = [:]
        let current = Dictionary(pool.map { ($0.id, Group($0.task.habit.timeOfDay)) }, uniquingKeysWith: { first, _ in first })
        for row in moved {
            switch row {
            case .header(let header):
                group = header
            case .item(let name):
                order.append(name)
                if current[name] != group { regrouped[name] = group }
            }
        }
        return Move(order: order, regrouped: regrouped)
    }
}
