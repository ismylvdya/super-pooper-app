import Foundation

/// Builds today's plan from stored data with the configs: one function for the app and the widgets,
/// so both always show the same day.
enum DayPlanning {
    /// `eventsKnown`: the calendars are readable and chosen, so a linked event that is missing is a problem.
    static func plan(config: AppConfig, settings: AppSettings, tasks: [TaskItem], events: [CalendarEvent],
                     reminders: [ReminderItem], dayState: DayState, sections: DaySections? = nil, context: DayContext,
                     eventsKnown: Bool) -> DayPlan {
        let state = dayState.day == context.today ? dayState : DayState(day: context.today)
        let inputs = DayInputs(tasks: usable(tasks, config: config, context: context), events: events, reminders: reminders,
                               skipped: Set(state.skipped), manualOrder: state.manualOrder,
                               routines: settings.habits.routines,
                               postponed: Set(state.postponed), timelineFilter: settings.timeline.shown, eventsKnown: eventsKnown,
                               timeMoves: state.timeMoves, sections: sections)
        return builder(config: config, settings: settings)
            .build(inputs, context: context)
    }

    /// Today, or another day `offset` days away (swiping on Today): that day's events, reminders and this week's
    /// tasks dated that day. "Past" is measured from the real now.
    static func plan(config: AppConfig, settings: AppSettings, tasks: [TaskItem], events: [CalendarEvent],
                     reminders: [ReminderItem], dayState: DayState, sections: DaySections? = nil, context: DayContext,
                     dayOffset: Int, eventsKnown: Bool) -> DayPlan {
        guard dayOffset != 0 else {
            return plan(config: config, settings: settings, tasks: tasks, events: events, reminders: reminders,
                        dayState: dayState, sections: sections, context: context, eventsKnown: eventsKnown)
        }
        let day = context.today.adding(days: dayOffset)
        // "Now" inside another day: the hour its timeline centres on (no cursor is drawn there).
        let dayContext = context.focused(on: context.moment(config.rules.timeline.otherDayAnchor, onLogicalDay: day))
        let moves = dayState.day == context.today ? dayState.moves(on: day) : []
        let inputs = DayInputs(tasks: usable(tasks, config: config, context: context), events: events, reminders: reminders,
                               skipped: [], manualOrder: nil, timelineFilter: settings.timeline.shown, isOtherDay: true,
                               eventsKnown: eventsKnown, timeMoves: moves, sections: sections)
        var result = builder(config: config, settings: settings).build(inputs, context: dayContext)
        result.isToday = false
        return result
    }

    /// Times kept in a zone of their own moved to the phone's.
    private static func usable(_ tasks: [TaskItem], config: AppConfig, context: DayContext) -> [TaskItem] {
        ZonedTimes.local(tasks, calendar: context.calendar, today: context.today)
    }

    private static func builder(config: AppConfig, settings: AppSettings) -> DayBuilder {
        DayBuilder(rules: config.rules.day, sortCriteria: sortCriteria(config: config, settings: settings),
                   sections: config.rules.pool.defaultSections)
    }

    /// The user's order of the pool rules, or `sort.json`; unknown names are skipped.
    static func sortCriteria(config: AppConfig, settings: AppSettings) -> [PoolSortCriterion] {
        let custom = settings.pool.criteria.compactMap(PoolSortCriterion.init(rawValue:))
        return custom.isEmpty ? config.sort.pool : custom
    }
}
