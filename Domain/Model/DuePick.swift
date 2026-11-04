import Foundation

/// What the date sheet holds while it is open: a day, an optional time and an optional zone. With no zone chosen
/// nothing about zones is written (the times follow the phone's clock); a zone is written only when it changed.
struct DuePick: Equatable, Sendable {
    var day: LocalDate
    var time: LocalTime?
    var zone: String?
    /// It rings as an alarm at its time.
    var alarm: TimeAlarm?

    init(day: LocalDate, time: LocalTime? = nil, zone: String? = nil, alarm: TimeAlarm? = nil) {
        self.day = day
        self.time = time
        self.zone = zone
        self.alarm = alarm
    }

    /// The sheet over a task: its due as written, or today without a time.
    init(task: TaskItem, today: LocalDate) {
        self.init(day: task.due?.day ?? today, time: task.due?.time, zone: task.timeZone, alarm: task.due?.time == nil ? nil : task.alarm(at: nil))
    }

    var due: TaskDue { TaskDue(day: day, time: time) }

    /// The edits Done writes to `task`: always its due, its zone and its alarm only when they changed.
    func edits(from task: TaskItem) -> [TaskEdit] {
        let rings = time == nil ? nil : alarm
        return [.due(due)] + (zone == task.timeZone ? [] : [.timeZone(zone)])
            + (rings == task.alarm(at: nil) ? [] : [.alarms(rings.map { [$0] } ?? [])])
    }
}
