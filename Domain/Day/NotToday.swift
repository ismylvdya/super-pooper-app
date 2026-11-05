import Foundation

/// Not today for an open task: its date goes and it waits in Next actions, out of the pool. A habit has Tomorrow, through its line.
enum NotToday {
    static func isAvailable(for item: DayItem) -> Bool {
        !item.isHabit && !item.isDone
    }

    static func changes() -> [TaskEdit] {
        [.due(nil)]
    }
}
