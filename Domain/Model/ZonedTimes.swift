import Foundation

/// Times of day are wall-clock times by default: 09:00 stays 09:00 wherever the phone is, no zone is stored. A task
/// or habit can keep its times in a zone of its own instead (its `timeZone`, set by the user); then its due time and
/// reminder times are read in that zone and moved to the phone's zone here, once, before the day and the notifications
/// are built — everything after that works with plain local times.
enum ZonedTimes {
    static func local(_ tasks: [TaskNote], calendar: Calendar, today: LocalDate) -> [TaskNote] {
        tasks.map { local($0, calendar: calendar, today: today) }
    }

    static func local(_ task: TaskNote, calendar: Calendar, today: LocalDate) -> TaskNote {
        guard let id = task.timeZone, let zone = TimeZone(identifier: id), zone.identifier != calendar.timeZone.identifier else {
            return task
        }
        var source = calendar
        source.timeZone = zone
        var result = task
        if let due = task.due, let time = due.time {
            let moved = convert(day: due.day, time: time, from: source, to: calendar)
            result.due = TaskDue(day: moved.day, time: moved.time)
        }
        // Reminder times have no day: they are moved as they fall today.
        result.reminderTimes = task.reminderTimes.map { convert(day: today, time: $0, from: source, to: calendar).time }
        return result
    }

    private static func convert(day: LocalDate, time: LocalTime, from source: Calendar, to target: Calendar)
        -> (day: LocalDate, time: LocalTime) {
        let moment = day.startDate(in: source, offset: time)
        let parts = target.dateComponents([.hour, .minute], from: moment)
        return (LocalDate(moment, in: target), LocalTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0) ?? time)
    }
}
