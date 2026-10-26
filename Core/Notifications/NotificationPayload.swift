import Foundation

/// `userInfo` keys and category ids shared by the scheduler, the notification delegate and the widgets (which clear
/// notifications of a day that is over).
enum NotificationPayload {
    static let prefix = "sp|"
    static let kindKey = "kind"
    static let taskKey = "task"
    static let dayKey = "day"
    static let reminderKey = "reminder"
    static let eventKey = "event"
    /// The event's start, seconds since 1970: a repeating event shares its identifier with its other occurrences.
    static let eventStartKey = "eventStart"
    static let habitCategory = "habit"
    static let taskCategory = "task"
    static let reminderCategory = "reminder"
    static let eventCategory = "event"
}
