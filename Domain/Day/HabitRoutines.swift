import Foundation

/// The user's order of the morning and evening routines (habits with that part of the day).
/// Habits not in the order follow it by name.
struct HabitRoutines: Hashable, Sendable {
    var morning: [String] = []
    var day: [String] = []
    var evening: [String] = []

    /// Position of a habit within its routine; nil for habits outside the routines.
    func position(of task: TaskNote) -> Int? {
        guard let part = task.habit.timeOfDay else { return nil }
        let order = self.order(part)
        return order.firstIndex { $0.isSameNoteName(as: task.name) } ?? order.count
    }

    /// The order of one routine.
    func order(_ part: HabitTimeOfDay) -> [String] {
        switch part {
        case .morning: morning
        case .day: day
        case .evening: evening
        }
    }

    /// The habits of one routine in routine order.
    static func members(_ part: HabitTimeOfDay, of habits: [TaskNote], order: [String]) -> [TaskNote] {
        HabitOrder.sorted(habits.filter { $0.habit.timeOfDay == part && !$0.isArchived }, order: order)
    }
}
