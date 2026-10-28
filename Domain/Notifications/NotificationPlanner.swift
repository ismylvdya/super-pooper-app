import Foundation

/// Decides which notifications should be pending: timed habits, timed tasks of this week, timed reminders
/// and the alerts of calendar events. Anything whose time has passed is never planned (better skipped
/// than late; `LateAlerts` covers items moved into the past).
///
/// A habit's next notification at each of its times reuses one identifier, so when it is delivered it
/// replaces the one left from an earlier day: an overdue day just stays undone, and the buttons act on
/// the new day.
struct NotificationPlanner: Sendable {
    let horizonDays: Int
    let limit: Int

    /// Upcoming notifications, nearest first, at most `limit`. `skipped`: names taken out of today
    /// (Skip today for habits, Not today for tasks).
    func plan(tasks: [TaskNote], reminders: [ReminderItem], events: [CalendarEvent] = [], skipped: Set<String>,
              context: DayContext) -> [PlannedNotification] {
        let upcoming = all(tasks: tasks, reminders: reminders, events: events, skipped: skipped, context: context)
            .filter { $0.fireDate > context.now }
        return Array(Self.reusingHabitSlots(upcoming).prefix(limit))
    }

    /// Today's notifications regardless of time: a delivered one stays in Notification Center
    /// only while it is still in this list.
    func stillValidToday(tasks: [TaskNote], reminders: [ReminderItem], events: [CalendarEvent] = [], skipped: Set<String>,
                         context: DayContext) -> [PlannedNotification] {
        let today = all(tasks: tasks, reminders: reminders, events: events, skipped: skipped, context: context)
            .filter { $0.day == context.today }
        // A delivered habit notification carries its slot identifier and its day: it stays while that day is
        // still open (an overdue day too), until the next one replaces it or the day gets marked.
        let earlier = context.with(now: context.dayStart.addingTimeInterval(-Double(horizonDays) * 86_400))
        let openSlots = NotificationPlanner(horizonDays: horizonDays + 1, limit: limit)
            .all(tasks: tasks, reminders: [], skipped: skipped, context: earlier)
            .filter { $0.kind == .habit && $0.day <= context.today }
            .filter { !($0.day == context.today && skipped.contains($0.taskName ?? "")) }
            .map { note in
                PlannedNotification(id: note.key, kind: note.kind, title: note.title, fireDate: note.fireDate,
                                    taskName: note.taskName, day: note.day, key: note.key)
            }
        return today + openSlots
    }

    /// Everything of today and the coming days, past times included (for late alerts).
    func all(tasks: [TaskNote], reminders: [ReminderItem], events: [CalendarEvent] = [], skipped: Set<String>,
             context: DayContext) -> [PlannedNotification] {
        let occurrence = TaskOccurrence(days: context.days)
        var result: [PlannedNotification] = []

        for task in tasks {
            if task.isHabit {
                guard !task.isArchived else { continue }
                let instances = HabitInstances(task: task)
                for offset in 0..<horizonDays {
                    let day = context.today.adding(days: offset)
                    guard occurrence.occurs(task, on: day),
                          !HabitMarking.isDayClosed(instances.mark(on: day), twiceADay: task.habit.twiceADay,
                                                    remindersPerDay: task.habitTimes.count) else { continue }
                    if day == context.today, skipped.contains(task.name) { continue }
                    for time in task.habitTimes {
                        result.append(PlannedNotification(id: "habit|\(task.name)|\(day.isoString)|\(time.string)", kind: .habit,
                                                          title: task.name, fireDate: context.moment(time, onLogicalDay: day),
                                                          taskName: task.name, day: day,
                                                          key: Self.habitSlot(task.name, time)))
                    }
                }
            } else if task.status == .thisWeek, let due = task.due, let time = due.time {
                let day = context.logicalDay(of: due)
                if day == context.today, skipped.contains(task.name) { continue }
                result.append(PlannedNotification(id: "task|\(task.name)", kind: .task, title: task.name,
                                                  fireDate: context.date(due.day, time), taskName: task.name,
                                                  day: day, key: "task|\(task.name)"))
            }
        }

        for reminder in reminders where !reminder.isCompleted {
            result.append(PlannedNotification(id: "reminder|\(reminder.id)|\(reminder.due.timeIntervalSince1970)", kind: .reminder,
                                              title: reminder.title, fireDate: reminder.due, taskName: nil,
                                              day: context.logicalDay(of: reminder.due), reminderID: reminder.id,
                                              key: "reminder|\(reminder.id)"))
        }

        let horizonEnd = context.today.adding(days: horizonDays).startDate(in: context.calendar, offset: context.boundary)
        for event in events where event.end > context.dayStart.addingTimeInterval(-86_400) {
            for (index, fire) in event.alarmDates.enumerated() where fire < horizonEnd {
                result.append(PlannedNotification(id: "event|\(event.eventIdentifier)|\(Int(event.start.timeIntervalSince1970))|\(index)",
                                                  kind: .event, title: event.title, fireDate: fire, taskName: nil,
                                                  day: context.logicalDay(of: event.start),
                                                  key: "event|\(event.eventIdentifier)|\(index)", start: event.start,
                                                  eventID: event.eventIdentifier))
            }
        }

        return result.sorted { $0.fireDate < $1.fireDate }
    }

    static func habitSlot(_ name: String, _ time: LocalTime) -> String { "habit|\(name)|\(time.string)" }

    /// The first upcoming notification of each habit time gets the slot identifier.
    private static func reusingHabitSlots(_ upcoming: [PlannedNotification]) -> [PlannedNotification] {
        var used: Set<String> = []
        return upcoming.map { note in
            guard note.kind == .habit, used.insert(note.key).inserted else { return note }
            return PlannedNotification(id: note.key, kind: note.kind, title: note.title, fireDate: note.fireDate,
                                       taskName: note.taskName, day: note.day, reminderID: note.reminderID,
                                       key: note.key, start: note.start)
        }
    }
}
