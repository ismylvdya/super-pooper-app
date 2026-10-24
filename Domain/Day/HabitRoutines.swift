import Foundation

/// The user's order of the morning and evening routines (habits with that part of the day).
/// Habits not in the order follow it by name.
struct HabitRoutines: Hashable, Sendable {
    var morning: [String] = []
    var evening: [String] = []

    /// Position of a habit within its routine; nil for habits outside the morning and evening routines.
    func position(of task: TaskNote) -> Int? {
        switch task.habit.timeOfDay {
        case .morning: morning.firstIndex { $0.isSameNoteName(as: task.name) } ?? morning.count
        case .evening: evening.firstIndex { $0.isSameNoteName(as: task.name) } ?? evening.count
        case .day, nil: nil
        }
    }

    /// The habits of one routine in routine order.
    static func members(_ part: HabitTimeOfDay, of habits: [TaskNote], order: [String]) -> [TaskNote] {
        HabitOrder.sorted(habits.filter { $0.habit.timeOfDay == part && !$0.isArchived }, order: order)
    }
}
