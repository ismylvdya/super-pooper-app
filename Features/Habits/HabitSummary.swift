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

    /// "3/5 this week" with a weekly goal, "3 this week" without; harmful habits count clean days.
    static func weekLine(_ habit: TaskItem, today: LocalDate, days: DayBoundary, rules: HabitStatsRules) -> String {
        let history = HabitHistory(task: habit, days: days)
        let units = history.weekUnits(containing: today, today: today, rules: rules)
        let count = units.rounded() == units ? String(Int(units)) : units.formatted(.number.precision(.fractionLength(1)))
        if habit.habit.harmful { return L10n.format("habits.week.harmful", count) }
        if case .weeklyGoal(let goal) = habit.habit.skipRule { return L10n.format("habits.week.goal", count, goal) }
        return L10n.format("habits.week.count", count)
    }
}
