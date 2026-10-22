import Foundation

/// Builds today's plan from stored data with the configs: one function for the app and the widgets,
/// so both always show the same day.
enum DayPlanning {
    static func plan(config: AppConfig, tasks: [TaskNote], events: [CalendarEvent], reminders: [ReminderItem],
                     dayState: DayState, context: DayContext) -> DayPlan {
        let state = dayState.day == context.today ? dayState : DayState(day: context.today)
        let usableTasks = config.flags.eventLinks ? tasks : tasks.map(\.withoutEventLinks)
        let inputs = DayInputs(tasks: usableTasks, events: events, reminders: reminders,
                               skipped: Set(state.skipped), manualOrder: state.manualOrder)
        return DayBuilder(rules: config.rules.day, sortCriteria: config.sort.pool).build(inputs, context: context)
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
