import Foundation

/// Answers "does this recurring task have an instance on that day", the way TaskNotes does.
struct TaskOccurrence: Sendable {
    let days: DayBoundary

    /// Unknown rules count as "every day" (TaskNotes shows such tasks everywhere too);
    /// the problem badge comes from the parser.
    func occurs(_ task: TaskNote, on day: LocalDate) -> Bool {
        guard task.isHabit else { return false }
        guard let schedule = schedule(of: task, fallbackDay: day) else { return true }
        return schedule.occurs(on: day)
    }

    func schedule(of task: TaskNote, fallbackDay: LocalDate) -> RecurrenceSchedule? {
        guard let rule = task.recurrence else { return nil }
        let created = task.dateCreated.map(days.day(of:))
        return RecurrenceSchedule(rule: rule, fallbackStart: task.due?.day ?? created ?? fallbackDay)
    }
}
