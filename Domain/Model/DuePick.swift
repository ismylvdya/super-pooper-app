import Foundation

/// What the date sheet holds while it is open: a day, an optional time and an optional zone. With no zone chosen
/// nothing about zones is written (the times follow the phone's clock); a zone is written only when it changed.
struct DuePick: Equatable, Sendable {
    var day: LocalDate
    var time: LocalTime?
    var zone: String?

    init(day: LocalDate, time: LocalTime? = nil, zone: String? = nil) {
        self.day = day
        self.time = time
        self.zone = zone
    }

    /// The sheet over a task: its due as written, or today without a time.
    init(task: TaskItem, today: LocalDate) {
        self.init(day: task.due?.day ?? today, time: task.due?.time, zone: task.timeZone)
    }

    var due: TaskDue { TaskDue(day: day, time: time) }

    /// The edits Done writes to `task`: always its due, its zone only when another one was picked.
    func edits(from task: TaskItem) -> [TaskEdit] {
        [.due(due)] + (zone == task.timeZone ? [] : [.timeZone(zone)])
    }
}
