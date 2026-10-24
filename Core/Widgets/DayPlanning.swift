import Foundation

/// Builds today's plan from stored data with the configs: one function for the app and the widgets,
/// so both always show the same day.
enum DayPlanning {
    static func plan(config: AppConfig, settings: AppSettings, tasks: [TaskNote], events: [CalendarEvent],
                     reminders: [ReminderItem], dayState: DayState, context: DayContext) -> DayPlan {
        let state = dayState.day == context.today ? dayState : DayState(day: context.today)
        let usableTasks = config.flags.eventLinks ? tasks : tasks.map(\.withoutEventLinks)
        let inputs = DayInputs(tasks: usableTasks, events: events, reminders: reminders,
                               skipped: Set(state.skipped), manualOrder: state.manualOrder,
                               routines: HabitRoutines(morning: settings.habits.morningRoutine, evening: settings.habits.eveningRoutine),
                               postponed: Set(state.postponed), timelineFilter: settings.timeline.shown)
        return DayBuilder(rules: config.rules.day, sortCriteria: sortCriteria(config: config, settings: settings))
            .build(inputs, context: context)
    }

    /// Today, or another day `offset` days away (swiping on Today): that day's events, reminders and dated tasks.
    static func plan(config: AppConfig, settings: AppSettings, tasks: [TaskNote], events: [CalendarEvent],
                     reminders: [ReminderItem], dayState: DayState, context: DayContext, dayOffset: Int) -> DayPlan {
        guard dayOffset != 0 else {
            return plan(config: config, settings: settings, tasks: tasks, events: events, reminders: reminders,
                        dayState: dayState, context: context)
        }
        let day = context.today.adding(days: dayOffset)
        let dayContext = context.with(now: OtherDay.moment(of: day, context: context, anchor: config.rules.timeline.otherDayAnchor))
        let inputs = DayInputs(tasks: OtherDay.tasks(tasks, on: day, context: dayContext), events: events, reminders: reminders,
                               skipped: [], manualOrder: nil, timelineFilter: settings.timeline.shown)
        var result = DayBuilder(rules: config.rules.day, sortCriteria: sortCriteria(config: config, settings: settings))
            .build(inputs, context: dayContext)
        result.isToday = false
        return result
    }

    /// The user's order of the pool rules, or `sort.json`; unknown names are skipped.
    static func sortCriteria(config: AppConfig, settings: AppSettings) -> [PoolSortCriterion] {
        let custom = settings.pool.criteria.compactMap(PoolSortCriterion.init(rawValue:))
        return custom.isEmpty ? config.sort.pool : custom
    }
}

private extension TaskNote {
    var withoutEventLinks: TaskNote {
        var copy = self
        copy.previousEvent = nil
        copy.nextEvent = nil
        return copy
    }
}
