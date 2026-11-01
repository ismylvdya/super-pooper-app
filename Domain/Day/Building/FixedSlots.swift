import Foundation

/// The timeline's blocks that stand at their own time: events of the day, the open times of timed tasks and habits,
/// and reminders that are not done.
struct FixedSlots: Sendable {
    let rules: DayRules
    let times: DayTimes

    func slots(timed: [DayItem], events: [CalendarEvent], reminders: [ReminderItem]) -> [TimelineSlot] {
        let context = times.context
        var slots: [TimelineSlot] = []
        for event in events where !event.isAllDay && times.overlapsToday(event) {
            slots.append(TimelineSlot(content: .event(event), start: event.start, end: event.end, isPast: event.end <= context.now,
                                      alerts: event.hasAlarm))
        }
        for item in timed {
            for time in times.openTimes(of: item) {
                let start = context.moment(time, onLogicalDay: context.today)
                slots.append(TimelineSlot(content: .task(item), start: start, end: start.addingTimeInterval(rules.duration(of: item.task)),
                                          isPast: false, time: time, alerts: true))
            }
        }
        for reminder in reminders where context.contains(reminder.due) && !reminder.isCompleted {
            slots.append(TimelineSlot(content: .reminder(reminder), start: reminder.due,
                                      end: reminder.due.addingTimeInterval(rules.reminderDuration), isPast: false, alerts: true))
        }
        return slots
    }
}
