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
    /// Finished events are drawn greyed out (done tasks and reminders leave the timeline).
    let isPast: Bool
    /// Which of a habit's several times of day this block is (it keeps the ids of the blocks apart).
    var time: LocalTime? = nil
    /// Something will alert at this block: a reminder, an event with a Calendar alert, a timed task or
    /// habit with its notification. The block shows the bell.
    var alerts = false

    var id: String {
        switch content {
        case .event(let event): "event:\(event.id)"
        case .task(let item): "task:\(item.id)" + (time.map { "@\($0.string)" } ?? "")
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
    /// All-day events of today: they have no place on the hour grid and sit in a strip above it.
    var allDayEvents: [CalendarEvent] = []
    /// False for another day browsed by swiping: no "now" cursor there.
    var isToday = true

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
