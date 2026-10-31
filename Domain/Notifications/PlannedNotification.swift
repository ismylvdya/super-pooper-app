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
    /// Start of the event an alert belongs to.
    var start: Date? = nil
    /// The calendar event an event alert deletes from its Delete event button.
    var eventID: String? = nil
    /// A habit's own color (hex) for the picture on its notification, if the settings use it.
    var colorHex: String? = nil
    /// The fire time is a moment, not a time on the clock: an event's alert, a timed reminder, an item with a time zone
    /// of its own. It rings at that moment even if the phone changes its zone first; the rest ring at their clock time.
    var isAbsolute = false

    /// The same notification under another identifier.
    func identified(as id: String) -> PlannedNotification {
        var copy = self
        copy.id = id
        return copy
    }
}
