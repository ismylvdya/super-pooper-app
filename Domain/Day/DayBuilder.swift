import Foundation

/// Decides what is in today, what goes to the pool and what goes to the timeline.
struct DayBuilder: Sendable {
    let rules: DayRules
    let sortCriteria: [PoolSortCriterion]
    /// The sections every day starts with (`rules.json` → `pool.defaultSections`).
    let sections: [PoolSectionDefinition]

    func build(_ inputs: DayInputs, context: DayContext) -> DayPlan {
        let occurrence = TaskOccurrence(days: context.days)
        let sorter = PoolSorter(criteria: sortCriteria, rules: rules, routines: inputs.routines)
        let membership = DayMembership(occurrence: occurrence, context: context,
                                       parents: RepeatableSubtasks.parents(in: inputs.tasks))
        let dayProblems = DayProblems(occurrence: occurrence)
        let times = DayTimes(context: context, todayTimes: TodayTimes(inputs.timeMoves), followsLines: inputs.isOtherDay)

        var items: [DayItem] = []
        var problems: [PlanProblem] = []
        // A task shown one at a time is in the day only through its next action, which carries the task's name (`TaskSteps`).
        let steps = TaskSteps.plan(in: inputs.tasks)
        for task in inputs.tasks {
            let inDay = inputs.isOtherDay
                ? membership.isOnOtherDay(task)
                : membership.isInDay(task, skipped: inputs.skipped)
            let taskProblems = dayProblems.problems(of: task)
            // Problems of done or archived tasks are not reported.
            if inDay || (task.isHabit && !task.isArchived) || !task.status.isCompleted {
                problems += taskProblems.map { PlanProblem(taskName: task.name, problem: $0) }
            }

            // A task shown as a project holds tasks; it is not one to do itself.
            guard inDay, !task.showsAsProject, !steps.waiting.contains(task.name), !steps.projects.contains(task.name) else { continue }
            var item = DayItem(task: task, state: membership.state(of: task), problems: taskProblems)
            item.project = steps.projectOf[task.name]
            items.append(item)
        }

        let timed = items.filter { inputs.timelineFilter.shows($0) && !times.times(of: $0.task).isEmpty }
        let shownTimed = timed.filter { !times.openTimes(of: $0).isEmpty }
        let timedNames = Set(timed.map(\.id))
        // Overdue blocks ride on the cursor of today only; on another day "now" is not on its timeline.
        let overdue = inputs.isOtherDay ? [:] : OverdueBlocks(rules: rules, times: times).starts(of: shownTimed)
        // Done today: it leaves the pool and the timeline instead of staying greyed out. A habit block dragged to the pool
        // today brings the habit there, even if another of its blocks stays on the timeline.
        let poolItems = items.filter { !$0.isFinished && (!timedNames.contains($0.id) || times.isPooledToday($0)) }

        let sorted = SubtaskNesting.nested(inputs.manualOrder.map { sorter.applyingManualOrder($0, to: poolItems, context: context) }
            ?? sorter.sorted(poolItems, context: context))
        let daySections = inputs.sections ?? .defaults(on: context.today, definitions: sections)
        // Every day's pool stands in the day's sections: Morning and Evening by a task's routine (`time_of_day`), the rest in
        // Day, and on that day's own sections what was moved into them.
        let arranged = PoolArrangement.arrange(sorted, sections: daySections, definitions: sections)
        let pool = arranged.isEmpty ? sorted : arranged.flatMap(\.items)

        var timeline = FixedSlots(rules: rules, times: times, overdue: overdue)
            .slots(timed: shownTimed, events: inputs.timelineFilter.events ? inputs.events : [],
                   reminders: inputs.timelineFilter.reminders ? inputs.reminders : [])
        timeline.sort { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }

        let allDay = inputs.events.filter { $0.isAllDay && $0.covers(context.today, calendar: context.calendar) }
            .sorted { NameOrder.precedes($0.title, $1.title) }
        var plan = DayPlan(today: context.today, now: context.now, pool: pool, timeline: timeline, problems: problems, allDayEvents: allDay)
        plan.focus = context.focus
        plan.sections = arranged
        plan.worms = inputs.isOtherDay ? [] : daySections.worms
        return plan
    }
}
