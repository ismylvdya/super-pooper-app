import Foundation

/// Today's screen content: the pool of untimed tasks and the timeline.
struct DayPlan: Sendable {
    let today: LocalDate
    let now: Date
    /// The pool in its shown order: the sections' tasks one section after another.
    let pool: [DayItem]
    let timeline: [TimelineSlot]
    let problems: [PlanProblem]
    /// All-day events of today: they have no place on the hour grid and sit in a strip above it.
    var allDayEvents: [CalendarEvent] = []
    /// The pool split into the day's sections (Morning, Day, Evening and the user's own).
    var sections: [PoolSectionContent] = []
    /// False for another day browsed by swiping: no "now" cursor there.
    var isToday = true
    /// The moment the timeline is centred on: `now` for today, the anchor hour of another day.
    var focus: Date?

    var timelineFocus: Date { focus ?? now }

    static func empty(today: LocalDate, now: Date) -> DayPlan {
        DayPlan(today: today, now: now, pool: [], timeline: [], problems: [])
    }
}
