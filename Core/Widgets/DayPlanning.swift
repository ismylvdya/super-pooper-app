import Foundation

/// Builds today's plan from stored data with the configs: one function for the app and the widgets,
/// so both always show the same day.
enum DayPlanning {
    /// `eventsKnown`: the calendars are readable and chosen, so a linked event that is missing is a problem.
    static func plan(config: AppConfig, settings: AppSettings, tasks: [TaskNote], events: [CalendarEvent],
                     reminders: [ReminderItem], dayState: DayState, context: DayContext, eventsKnown: Bool = true) -> DayPlan {
        let state = dayState.day == context.today ? dayState : DayState(day: context.today)
        let inputs = DayInputs(tasks: usable(tasks, config: config), events: events, reminders: reminders,
                               skipped: Set(state.skipped), manualOrder: state.manualOrder,
                               routines: HabitRoutines(morning: settings.habits.morningRoutine, evening: settings.habits.eveningRoutine),
                               postponed: Set(state.postponed), timelineFilter: settings.timeline.shown, eventsKnown: eventsKnown)
        return DayBuilder(rules: config.rules.day, sortCriteria: sortCriteria(config: config, settings: settings))
            .build(inputs, context: context)
    }

    /// Today, or another day `offset` days away (swiping on Today): that day's events, reminders and this week's
    /// tasks dated that day. "Past" and blocking are measured from the real now; links reach every task.
    static func plan(config: AppConfig, settings: AppSettings, tasks: [TaskNote], events: [CalendarEvent],
                     reminders: [ReminderItem], dayState: DayState, context: DayContext, dayOffset: Int,
                     eventsKnown: Bool = true) -> DayPlan {
        guard dayOffset != 0 else {
            return plan(config: config, settings: settings, tasks: tasks, events: events, reminders: reminders,
                        dayState: dayState, context: context, eventsKnown: eventsKnown)
        }
        let day = context.today.adding(days: dayOffset)
        let dayContext = context.focused(on: OtherDay.moment(of: day, context: context, anchor: config.rules.timeline.otherDayAnchor))
        let inputs = DayInputs(tasks: usable(tasks, config: config), events: events, reminders: reminders,
                               skipped: [], manualOrder: nil, timelineFilter: settings.timeline.shown, isOtherDay: true,
                               eventsKnown: eventsKnown)
        var result = DayBuilder(rules: config.rules.day, sortCriteria: sortCriteria(config: config, settings: settings))
            .build(inputs, context: dayContext)
        result.isToday = false
        return result
    }

    /// Event links are dropped when the feature is off.
    private static func usable(_ tasks: [TaskNote], config: AppConfig) -> [TaskNote] {
        config.flags.eventLinks ? tasks : tasks.map(\.withoutEventLinks)
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
