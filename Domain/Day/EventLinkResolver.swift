import Foundation

/// Finds the calendar event a task link points to: by identifier on the same day
/// (recurring events share the identifier), then by title and start time.
struct EventLinkResolver: Sendable {
    let events: [CalendarEvent]
    let calendar: Calendar

    func resolve(_ link: EventLink) -> CalendarEvent? {
        let linkDay = LocalDate(link.start, in: calendar)
        let sameIdentifier = events.filter {
            $0.eventIdentifier == link.eventIdentifier && LocalDate($0.start, in: calendar) == linkDay
        }
        if let match = sameIdentifier.min(by: { abs($0.start.timeIntervalSince(link.start)) < abs($1.start.timeIntervalSince(link.start)) }) {
            return match
        }
        return events.first { $0.title == link.title && abs($0.start.timeIntervalSince(link.start)) < 60 }
    }
}
