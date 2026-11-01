import Foundation

/// Everything a day plan is worked out from. The lists compare in no time while they are the same arrays (unchanged
/// since the last plan).
struct PlanKey: Equatable {
    let tasks: [TaskItem]
    let events: [CalendarEvent]
    let reminders: [ReminderItem]
    let dayState: DayState
    let settings: AppSettings
    let calendar: Calendar
    let eventsKnown: Bool
    let minute: Date

    static func minute(of date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
    }
}

struct CachedPlan {
    let key: PlanKey
    let plan: DayPlan
}
