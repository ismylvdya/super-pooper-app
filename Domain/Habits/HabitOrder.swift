import Foundation

/// The habit list order: the user's dragged order first, everything else alphabetically after it.
enum HabitOrder {
    static func sorted(_ habits: [TaskNote], order: [String]) -> [TaskNote] {
        let position = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return habits.sorted { lhs, rhs in
            switch (position[lhs.name], position[rhs.name]) {
            case let (left?, right?): return left < right
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }
}
