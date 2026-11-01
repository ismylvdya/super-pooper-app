import Foundation

/// The timeline's blocks that stand at their own time: events of the day, the open times of timed tasks and habits (a
/// habit's block dragged today at its new time, still named by the time its note has), and reminders that are not done.
/// An overdue task rides on the "now" cursor instead (`OverdueTasks`): its alert is over, so its block has no bell.
struct FixedSlots: Sendable {
    let rules: DayRules
    let times: DayTimes
    /// Where overdue tasks start now, by item id.
    var overdue: [String: Date] = [:]

    func slots(timed: [DayItem], events: [CalendarEvent], reminders: [ReminderItem]) -> [TimelineSlot] {
        let context = times.context
        var slots: [TimelineSlot] = []
        for event in events where !event.isAllDay && times.overlapsToday(event) {
            slots.append(TimelineSlot(content: .event(event), start: event.start, end: event.end, isPast: event.end <= context.now,
                                      alerts: event.hasAlarm))
        }
        for item in timed {
            for block in times.openTimes(of: item) {
                let late = overdue[item.id]
                let start = late ?? times.moment(of: block)
                slots.append(TimelineSlot(content: .task(item), start: start, end: start.addingTimeInterval(rules.duration(of: item.task)),
                                          isPast: false, time: block.written, alerts: late == nil))
            }
        }
        for reminder in reminders where context.contains(reminder.due) && !reminder.isCompleted {
            slots.append(TimelineSlot(content: .reminder(reminder), start: reminder.due,
                                      end: reminder.due.addingTimeInterval(rules.reminderDuration), isPast: false, alerts: true))
        }
        return slots
    }
}
