import Foundation

/// Reference from a task to a calendar event: the event's identifier, its title and its start. Recurring events share
/// one identifier, so the start pins the instance.
struct EventLink: Hashable, Codable, Sendable {
    let eventIdentifier: String
    let title: String
    let start: Date

    init(eventIdentifier: String, title: String, start: Date) {
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.start = start
    }
}
