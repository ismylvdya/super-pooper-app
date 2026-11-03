import Foundation

/// Decides what is in today, what goes to the pool and what goes to the timeline.
struct DayBuilder: Sendable {
    let rules: DayRules
    let sortCriteria: [PoolSortCriterion]
    /// The sections every day starts with (`rules.json` → `pool.defaultSections`).
    let sections: [PoolSectionDefinition]

    func build(_ inputs: DayInputs, context: DayContext) -> DayPlan {
        let graph = TaskGraph(tasks: inputs.tasks)
        let occurrence = TaskOccurrence(days: context.days)
        let resolver = EventLinkResolver(events: inputs.events, calendar: context.calendar, tolerance: rules.eventLinkToleranceSeconds)
        let blocking = BlockingEvaluator(graph: graph, occurrence: occurrence, skipped: inputs.skipped, context: context)
        let sorter = PoolSorter(criteria: sortCriteria, rules: rules, routines: inputs.routines)
        let membership = DayMembership(occurrence: occurrence, context: context)
        let dayProblems = DayProblems(graph: graph, occurrence: occurrence)
        let times = DayTimes(context: context, todayTimes: TodayTimes(inputs.timeMoves))

        var items: [DayItem] = []
        var anchors: [String: TimelineChain.Anchor] = [:]
        var problems: [PlanProblem] = []
        for task in inputs.tasks {
            let previousEvent = task.previousEvent.flatMap(resolver.resolve)
            let nextEvent = task.nextEvent.flatMap(resolver.resolve)
            let inDay = inputs.isOtherDay
                ? membership.isOnOtherDay(task)
                : membership.isInDay(task, skipped: inputs.skipped) && !inputs.postponed.containsNoteName(task.name)
            let taskProblems = dayProblems.problems(of: task, previousEvent: previousEvent, nextEvent: nextEvent,
                                                    checkEvents: inDay && inputs.eventsKnown)
            // Problems of done or archived tasks are not reported.
            if inDay || (task.isHabit && !task.isArchived) || !task.status.isCompleted {
                problems += taskProblems.map { PlanProblem(taskName: task.name, problem: $0) }
            }

            guard inDay else { continue }
            items.append(DayItem(task: task, state: membership.state(of: task),
                                 blockers: blocking.blockers(for: task, previousEvent: previousEvent),
                                 problems: taskProblems))
            if let event = previousEvent, times.overlapsToday(event) {
                anchors[task.name] = .after(TimelineChain.Target(event: event))
            } else if let event = nextEvent, times.overlapsToday(event) {
                anchors[task.name] = .before(TimelineChain.Target(event: event))
            }
        }

        let timed = items.filter { inputs.timelineFilter.shows($0) && !times.times(of: $0.task).isEmpty }
        let shownTimed = timed.filter { !times.openTimes(of: $0).isEmpty }
        let timedNames = Set(timed.map(\.id))
        // Overdue blocks ride on the cursor of today only; on another day "now" is not on its timeline.
        let overdue = inputs.isOtherDay ? [:] : OverdueBlocks(rules: rules, times: times).starts(of: shownTimed)
        let targets = Dictionary(shownTimed.compactMap { item in
            times.target(of: item, rules: rules, overdue: overdue).map { (item.id, $0) }
        }, uniquingKeysWith: { first, _ in first })
        let chainAnchors = ChainAnchors.propagate(anchors, timed: targets, through: items.filter { !timedNames.contains($0.id) },
                                                  graph: graph)
        // Done today: it leaves the pool and the timeline instead of staying greyed out. A habit block dragged to the pool
        // today brings the habit there, even if another of its blocks stays on the timeline.
        let poolItems = items.filter {
            !$0.isFinished && (!timedNames.contains($0.id) || times.isPooledToday($0)) && chainAnchors[$0.id] == nil
        }

        let sorted = SubtaskNesting.nested(inputs.manualOrder.map { sorter.applyingManualOrder($0, to: poolItems, graph: graph, context: context) }
            ?? sorter.sorted(poolItems, graph: graph, context: context))
        let daySections = inputs.sections ?? .defaults(on: context.today, definitions: sections)
        let arranged = PoolArrangement.arrange(sorted, sections: daySections, definitions: sections)
        let pool = arranged.isEmpty ? sorted : arranged.flatMap(\.items)

        var timeline = FixedSlots(rules: rules, times: times, overdue: overdue)
            .slots(timed: shownTimed, events: inputs.timelineFilter.events ? inputs.events : [],
                   reminders: inputs.timelineFilter.reminders ? inputs.reminders : [])
        let chainLayout = ChainLayout(rules: rules)
        for chain in ChainAnchors.chains(items: items, anchors: chainAnchors, sorter: sorter, graph: graph, context: context) {
            timeline += chainLayout.entries(for: chain, now: context.focus)
        }
        timeline.sort { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }

        let allDay = inputs.events.filter { $0.isAllDay && $0.covers(context.today, calendar: context.calendar) }
            .sorted { NameOrder.precedes($0.title, $1.title) }
        var plan = DayPlan(today: context.today, now: context.now, pool: pool, timeline: timeline, problems: problems, allDayEvents: allDay)
        plan.focus = context.focus
        plan.sections = arranged
        plan.worms = daySections.worms
        return plan
    }
}
