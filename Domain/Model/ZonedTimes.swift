import Foundation

/// Times of day are wall-clock times by default: 09:00 stays 09:00 wherever the phone is, no zone is stored. A task
/// or habit can keep its times in a zone of its own instead (its `timeZone`, set by the user); then its due time and
/// reminder times are read in that zone and moved to the phone's zone here (`local`), once, before the day and the
/// notifications are built — everything after that works with plain local times. A time decided on that local view
/// (dropped on the timeline, moved to tomorrow, picked in This week) goes back into the item's zone before it is
/// written (`stored`).
enum ZonedTimes {
    static func local(_ tasks: [TaskNote], calendar: Calendar, today: LocalDate) -> [TaskNote] {
        tasks.map { local($0, calendar: calendar, today: today) }
    }

    static func local(_ task: TaskNote, calendar: Calendar, today: LocalDate) -> TaskNote {
        guard let source = ownCalendar(of: task, phone: calendar) else { return task }
        var result = task
        result.due = task.due.map { convert($0, from: source, to: calendar) }
        // Reminder times have no day: they are moved as they fall today.
        result.reminderTimes = task.reminderTimes.map { convert(TaskDue(day: today, time: $0), from: source, to: calendar).time ?? $0 }
        return result
    }

    /// A due on the phone's clock, as the task keeps it in its own zone.
    static func stored(_ due: TaskDue?, of task: TaskNote, calendar: Calendar) -> TaskDue? {
        guard let due, let target = ownCalendar(of: task, phone: calendar) else { return due }
        return convert(due, from: calendar, to: target)
    }

    /// Changes decided on the local view of `task` (the note as written), with their dates and times in its own zone.
    static func stored(_ changes: [TaskEdit], of task: TaskNote, calendar: Calendar) -> [TaskEdit] {
        changes.map { change in
            guard case .due(let due) = change else { return change }
            return .due(stored(due, of: task, calendar: calendar))
        }
    }

    /// The calendar on whose clock the task keeps its times: its own zone, or the phone's.
    static func calendar(of task: TaskNote, phone calendar: Calendar) -> Calendar {
        ownCalendar(of: task, phone: calendar) ?? calendar
    }

    /// The task's own zone when it has one other than the phone's.
    private static func ownCalendar(of task: TaskNote, phone calendar: Calendar) -> Calendar? {
        guard let id = task.timeZone, let zone = TimeZone(identifier: id), zone.identifier != calendar.timeZone.identifier else {
            return nil
        }
        var own = calendar
        own.timeZone = zone
        return own
    }

    /// A date alone has no moment and stays as it is; a date with a time moves to the same moment in `target`.
    private static func convert(_ due: TaskDue, from source: Calendar, to target: Calendar) -> TaskDue {
        guard let time = due.time else { return due }
        let moment = due.day.startDate(in: source, offset: time)
        return TaskDue(day: LocalDate(moment, in: target), time: LocalTime(moment, in: target))
    }
}
