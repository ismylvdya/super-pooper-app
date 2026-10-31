import Foundation

/// The day plan, worked out once per change of its data and per minute: a screen asks for it several times per drawing
/// (the problem count three times, the settings preview once per row).
extension AppModel {
    func plan(at date: Date) -> DayPlan {
        plan(at: date, dayOffset: 0)
    }

    /// Today (`dayOffset` 0) or another day browsed on Today.
    func plan(at date: Date, dayOffset: Int) -> DayPlan {
        let key = PlanKey(tasks: tasks, events: events, reminders: reminders, dayState: dayState, settings: settings,
                          calendar: calendar, eventsKnown: eventsKnown, minute: PlanKey.minute(of: date))
        if let cached = plans[dayOffset], cached.key == key { return cached.plan }
        let plan = DayPlanning.plan(config: config, settings: settings, tasks: tasks, events: events, reminders: reminders,
                                    dayState: dayState, context: context(at: date), dayOffset: dayOffset, eventsKnown: eventsKnown)
        plans[dayOffset] = CachedPlan(key: key, plan: plan)
        return plan
    }

    var problemCount: Int { fileProblems.count + plan(at: clock.now).problems.count }

    /// Without Calendar access or chosen calendars, a linked event cannot be looked up.
    var eventsKnown: Bool {
        services.calendars.access == .granted && !settings.sources.anchorCalendarIDs.isEmpty
    }
}

/// Everything a plan is worked out from. The lists compare in no time while they are the same arrays (unchanged
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
