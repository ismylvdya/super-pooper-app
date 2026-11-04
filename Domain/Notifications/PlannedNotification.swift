import Foundation

/// A local notification the app wants to have pending.
struct PlannedNotification: Hashable, Sendable {
    enum Kind: String, Sendable {
        case habit
        case task
        case reminder
        /// An alert of a calendar event (the app sends it instead of Calendar).
        case event
    }

    /// What the notification's text calls the item: a habit notification of a repeatable task says so.
    enum Subject: String, CaseIterable, Sendable {
        case habit
        case repeatable
        case task
        case reminder
        case event
    }

    var id: String
    let kind: Kind
    let title: String
    let fireDate: Date
    /// The task the notification acts on (nil for reminders and events).
    let taskName: String?
    /// The day the notification belongs to (habit marks are written for this day).
    let day: LocalDate
    /// The Reminders item a reminder notification completes.
    var reminderID: String? = nil
    /// The same alert across moves (an event's start or a task's time may change; this does not).
    var key: String = ""
    /// The time a task's or habit's block has in its note: which block of today a snooze moves (`TodayTimes`).
    var slot: LocalTime? = nil
    /// Start of the event an alert belongs to.
    var start: Date? = nil
    /// The calendar event an event alert deletes from its Delete event button.
    var eventID: String? = nil
    /// A habit's own color (hex) for the picture on its notification, if the settings use it.
    var colorHex: String? = nil
    /// The fire time is a moment, not a time on the clock: an event's alert, a timed reminder, an item with a time zone
    /// of its own. It rings at that moment even if the phone changes its zone first; the rest ring at their clock time.
    var isAbsolute = false
    /// A block dragged or snoozed to another time for today only: a habit's rings under an identifier of its own (with
    /// its time), never the slot's, so the slot's request waits for the next day and a shown notification of the slot goes.
    var isMoved = false
    /// A habit notification of a habit marked repeatable (a task that simply repeats).
    var isRepeatable = false
    /// It also rings as an alarm (`AlarmPlanner`), so the notification itself makes no sound.
    var hasAlarm = false

    var subject: Subject {
        switch kind {
        case .habit: isRepeatable ? .repeatable : .habit
        case .task: .task
        case .reminder: .reminder
        case .event: .event
        }
    }

    /// The same notification under another identifier.
    func identified(as id: String) -> PlannedNotification {
        var copy = self
        copy.id = id
        return copy
    }

    /// The same notification again at `moment` (snoozed): the same title, text and buttons, at that moment wherever the
    /// phone is, under an id of its own, so it never takes the place of a habit slot's pending request.
    func snoozed(until moment: Date) -> PlannedNotification {
        PlannedNotification(id: "snooze|\(key)|\(day.isoString)", kind: kind, title: title, fireDate: moment, taskName: taskName,
                            day: day, reminderID: reminderID, key: key, slot: slot, start: start, eventID: eventID, colorHex: colorHex,
                            isAbsolute: true, isRepeatable: isRepeatable)
    }
}
