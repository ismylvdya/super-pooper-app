import Foundation

/// Short texts about a habit for lists.
@MainActor
enum HabitSummary {
    /// "3/5 this week" with a weekly goal, "3 this week" without; harmful habits count clean days.
    static func weekLine(_ habit: TaskNote, today: LocalDate, days: DayBoundary) -> String {
        let history = HabitHistory(task: habit, days: days)
        let units = history.weekUnits(containing: today, today: today)
        let count = units.rounded() == units ? String(Int(units)) : units.formatted(.number.precision(.fractionLength(1)))
        if habit.habit.harmful { return L10n.format("habits.week.harmful", count) }
        if case .weeklyGoal(let goal) = habit.habit.skipRule { return L10n.format("habits.week.goal", count, goal) }
        return L10n.format("habits.week.count", count)
    }
}
