import Foundation

/// Short texts about a habit for lists.
@MainActor
enum HabitSummary {
    /// What sets the habit apart in the Habits list: its routine and Twice ("Morning · Twice"); empty if neither.
    static func traits(_ habit: TaskNote) -> String {
        var parts: [String] = []
        if let part = habit.habit.timeOfDay { parts.append(L10n.string("habitPage.timeOfDay." + part.rawValue)) }
        if habit.isTwiceADay { parts.append(L10n.string("action.twice")) }
        return parts.joined(separator: L10n.string("habits.traits.separator"))
    }

    /// A bell per reminder of the day, two at most.
    static func bellCount(_ habit: TaskNote, limit: Int) -> Int { min(habit.reminderTimes.count, limit) }

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
