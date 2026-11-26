import Foundation

/// Scheduled days without an amount contribute zero. Entries on unscheduled days also count.
struct HabitQuantityStats {
    let recordedDays: Int
    let attemptedDays: Int
    let total: Double
    let average: Double?
    let maximum: Int?

    init(task: TaskItem, today: LocalDate, days: DayBoundary) {
        let history = HabitHistory(task: task, days: days)
        let entries = (task.quantities ?? [:]).filter { $0.key <= today && $0.value.mark != nil }
        let start = min(history.start(today: today), entries.keys.min() ?? today)
        var daysCounted = 0
        var day = start
        while day <= today {
            if entries[day] != nil || history.isScheduled(day) { daysCounted += 1 }
            day = day.adding(days: 1)
        }
        let amounts = entries.values.compactMap(\.amount)
        recordedDays = entries.count
        attemptedDays = entries.values.filter { $0 == .partial }.count
        total = amounts.reduce(0) { $0 + Double($1) }
        average = daysCounted == 0 ? nil : total / Double(daysCounted)
        maximum = daysCounted == 0 ? nil : amounts.max() ?? 0
    }
}
