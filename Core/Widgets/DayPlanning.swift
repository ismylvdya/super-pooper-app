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
                               postponed: Set(state.postponed))
        return DayBuilder(rules: config.rules.day, sortCriteria: sortCriteria(config: config, settings: settings))
            .build(inputs, context: context)
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
