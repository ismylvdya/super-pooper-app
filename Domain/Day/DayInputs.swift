import Foundation

/// Raw material for one day.
struct DayInputs: Sendable {
    var tasks: [TaskItem]
    /// Events of the anchor calendars around today (also used to resolve task links).
    var events: [CalendarEvent]
    /// Timed reminders for today from the selected lists.
    var reminders: [ReminderItem]
    /// Recurring tasks hidden with "Skip today".
    var skipped: Set<String>
    /// The user's pool order for today, if they dragged something.
    var manualOrder: [String]?
    var routines = HabitRoutines()
    /// Tasks the morning review moved out of today (they stay this week).
    var postponed: Set<String> = []
    /// Which kinds of entries the timeline shows; hidden timed tasks and habits stay in the pool.
    var timelineFilter = TimelineFilter()
    /// Another day than today: this week's tasks dated that day and the habits shown in Today that repeat on it.
    var isOtherDay = false
    /// The calendars are readable and chosen: a link to an event that is not found is a problem.
    var eventsKnown = true
}
