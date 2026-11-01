import Foundation

/// What a timeline block shows.
enum TimelineContent: Hashable, Sendable {
    case event(CalendarEvent)
    case task(DayItem)
    case reminder(ReminderItem)

    /// What the block shows, by kind and id: a block's id, and what a chain hangs on (`TimelineChain.Target`).
    var id: String {
        switch self {
        case .event(let event): "event:\(event.id)"
        case .task(let item): "task:\(item.id)"
        case .reminder(let reminder): "reminder:\(reminder.id)"
        }
    }
}
