import Foundation

/// Decides which notifications should be pending: timed habits, timed tasks of this week, timed reminders
/// and the alerts of calendar events. Anything whose time has passed is never planned (better skipped
/// than late; `LateAlerts` covers items moved into the past).
///
/// A habit's next notification at each of its times reuses one identifier, so when it is delivered it
/// replaces the one left from an earlier day: an overdue day just stays undone, and the buttons act on
/// the new day. A notification lives its logical day (`StaleNotifications`): one of a day that is over is not kept.
/// Today a habit rings at its times as today has them (`HabitDayTimes`): a block dragged to another time rings there, one
/// dropped in the pool does not ring today; the next days ring as the note has it.
struct NotificationPlanner: Sendable {
    let horizonDays: Int
    let limit: Int

    /// Upcoming notifications, nearest first, at most `limit`. `skipped`: names taken out of today
    /// (Skip today for habits, Not today for tasks).
    func plan(tasks: [TaskItem], reminders: [ReminderItem], events: [CalendarEvent] = [], skipped: Set<String>,
              habitTimes: HabitDayTimes = HabitDayTimes(), context: DayContext) -> [PlannedNotification] {
        let upcoming = all(tasks: tasks, reminders: reminders, events: events, skipped: skipped, habitTimes: habitTimes,
                           context: context)
            .filter { $0.fireDate > context.now }
        return Array(Self.reusingHabitSlots(upcoming).prefix(limit))
    }

    /// Today's notifications regardless of time: a delivered one stays in Notification Center only while it is still in
    /// this list, so one of a day that is over goes, marked or not, as the widgets clear it at the boundary.
    func stillValidToday(tasks: [TaskItem], reminders: [ReminderItem], events: [CalendarEvent] = [], skipped: Set<String>,
                         habitTimes: HabitDayTimes = HabitDayTimes(), context: DayContext) -> [PlannedNotification] {
        let today = all(tasks: tasks, reminders: reminders, events: events, skipped: skipped, habitTimes: habitTimes,
                        context: context)
            .filter { $0.day == context.today }
        // A delivered habit notification may carry its slot identifier: it stays while today's slot is open where its
        // note puts it (a block dragged elsewhere or to the pool takes it away).
        let slots = today.filter { $0.kind == .habit && !$0.isMoved }.map { $0.identified(as: $0.key) }
        return today + slots
    }

    /// Everything of today and the coming days, past times included (for late alerts).
    func all(tasks: [TaskItem], reminders: [ReminderItem], events: [CalendarEvent] = [], skipped: Set<String>,
             habitTimes: HabitDayTimes = HabitDayTimes(), context: DayContext) -> [PlannedNotification] {
        let occurrence = TaskOccurrence(days: context.days)
        var result: [PlannedNotification] = []

        for task in tasks {
            if task.isHabit {
                guard !task.isArchived else { continue }
                let schedule = occurrence.schedule(of: task)
                for offset in 0..<horizonDays {
                    let day = context.today.adding(days: offset)
                    guard schedule.occurs(on: day),
                          !HabitMarking.isDayClosed(task.mark(on: day), twiceADay: task.isTwiceADay) else { continue }
                    if day == context.today, skipped.containsNoteName(task.name) { continue }
                    let blocks = day == context.today ? habitTimes.blocks(of: task) : task.habitTimes.map(BlockTime.init)
                    for block in blocks {
                        let slot = block.written
                        result.append(PlannedNotification(id: "habit|\(task.name)|\(day.isoString)|\(slot.string)", kind: .habit,
                                                          title: task.name, fireDate: context.moment(block.time, onLogicalDay: day),
                                                          taskName: task.name, day: day,
                                                          key: Self.habitSlot(task.name, slot), colorHex: task.habit.color,
                                                          isAbsolute: task.timeZone != nil, isMoved: block.isMoved,
                                                          isRepeatable: task.kind == .repeatable))
                    }
                }
            } else if task.status == .thisWeek, let due = task.due, let time = due.time {
                let day = context.logicalDay(of: due)
                if day == context.today, skipped.containsNoteName(task.name) { continue }
                result.append(PlannedNotification(id: "task|\(task.name)", kind: .task, title: task.name,
                                                  fireDate: context.date(due.day, time), taskName: task.name,
                                                  day: day, key: "task|\(task.name)", isAbsolute: task.timeZone != nil))
            }
        }

        for reminder in reminders where !reminder.isCompleted {
            result.append(PlannedNotification(id: "reminder|\(reminder.id)|\(reminder.due.timeIntervalSince1970)", kind: .reminder,
                                              title: reminder.title, fireDate: reminder.due, taskName: nil,
                                              day: context.logicalDay(of: reminder.due), reminderID: reminder.id,
                                              key: "reminder|\(reminder.id)", isAbsolute: true))
        }

        let horizonEnd = context.today.adding(days: horizonDays).startDate(in: context.calendar, offset: context.boundary)
        let yesterdayStart = context.date(context.today.adding(days: -1), context.boundary)
        for event in events where event.end > yesterdayStart {
            for (index, fire) in event.alarmDates.enumerated() where fire < horizonEnd {
                result.append(PlannedNotification(id: "event|\(event.eventIdentifier)|\(Int(event.start.timeIntervalSince1970))|\(index)",
                                                  kind: .event, title: event.title, fireDate: fire, taskName: nil,
                                                  day: context.logicalDay(of: event.start),
                                                  key: "event|\(event.eventIdentifier)|\(index)", start: event.start,
                                                  eventID: event.eventIdentifier, isAbsolute: true))
            }
        }

        return result.sorted { $0.fireDate < $1.fireDate }
    }

    static func habitSlot(_ name: String, _ time: LocalTime) -> String { "habit|\(name)|\(time.string)" }

    /// The first upcoming notification of each habit time at its own time gets the slot identifier.
    private static func reusingHabitSlots(_ upcoming: [PlannedNotification]) -> [PlannedNotification] {
        var used: Set<String> = []
        return upcoming.map { note in
            guard note.kind == .habit, !note.isMoved, used.insert(note.key).inserted else { return note }
            return note.identified(as: note.key)
        }
    }
}
