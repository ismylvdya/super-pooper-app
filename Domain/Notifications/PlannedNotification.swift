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

    let id: String
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
    /// A habit's own color (hex) for the picture on its notification; nil = the settings' habit color.
    var colorHex: String? = nil
}
