import Foundation

/// The day a habit or repeatable task comes up next, as its page says under its rule: the day its line in the file
/// stands on — an overdue one's too — else, with no line yet (a draft), the first day of its rule from today on.
enum NextRepeat {
    static func day(of task: TaskItem, today: LocalDate, occurrence: TaskOccurrence) -> LocalDate? {
        if let line = task.nextLine { return line.day }
        return occurrence.schedule(of: task).recurrence?.firstDay(onOrAfter: today)
    }
}
