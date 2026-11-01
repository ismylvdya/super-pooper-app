import Foundation

/// Short texts about a habit for lists.
@MainActor
enum HabitSummary {
    /// What sets the habit apart in the Habits list: its routine and Twice, each shown as its own icon.
    static func traits(_ habit: TaskItem) -> [HabitTrait] {
        var traits: [HabitTrait] = []
        if let part = habit.habit.timeOfDay { traits.append(.routine(part)) }
        if habit.isTwiceADay { traits.append(.twiceADay) }
        return traits
    }

    /// A bell per reminder of the day, two at most.
    static func bellCount(_ habit: TaskItem, limit: Int) -> Int { min(habit.reminderTimes.count, limit) }
}
