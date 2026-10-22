import Foundation

/// What a timeline block shows.
enum TimelineContent: Hashable, Sendable {
    case event(CalendarEvent)
    case task(DayItem)
    case reminder(ReminderItem)
}

struct TimelineSlot: Identifiable, Hashable, Sendable {
    let content: TimelineContent
    let start: Date
    let end: Date
    /// Finished events and done tasks are drawn greyed out.
    let isPast: Bool

    var id: String {
        switch content {
        case .event(let event): "event:\(event.id)"
        case .task(let item): "task:\(item.id)"
        case .reminder(let reminder): "reminder:\(reminder.id)"
        }
    }
}

/// A problem tied to a task, for the problems badge and banners.
struct PlanProblem: Hashable, Sendable {
    let taskName: String
    let problem: TaskProblem
}

/// Today's screen content: the pool of untimed tasks and the timeline.
struct DayPlan: Sendable {
    let today: LocalDate
    let now: Date
    let pool: [DayItem]
    let timeline: [TimelineSlot]
    let problems: [PlanProblem]

    static func empty(today: LocalDate, now: Date) -> DayPlan {
        DayPlan(today: today, now: now, pool: [], timeline: [], problems: [])
    }

    func item(named name: String) -> DayItem? {
        if let item = pool.first(where: { $0.id == name }) { return item }
        for entry in timeline {
            if case .task(let item) = entry.content, item.id == name { return item }
        }
        return nil
    }
}
