import Foundation

/// Raw material for one day.
struct DayInputs: Sendable {
    var tasks: [TaskNote]
    /// Events of the anchor calendars around today (also used to resolve task links).
    var events: [CalendarEvent]
    /// Timed reminders for today from the selected lists.
    var reminders: [ReminderItem]
    /// Recurring tasks hidden with "Skip today".
    var skipped: Set<String>
    /// The user's pool order for today, if they dragged something.
    var manualOrder: [String]?
    var routines = HabitRoutines()
    /// Tasks the morning review moved out of today (they stay this week).
    var postponed: Set<String> = []
    /// Which kinds of entries the timeline shows; hidden timed tasks and habits stay in the pool.
    var timelineFilter = TimelineFilter()
    /// Another day than today: this week's tasks dated that day and the habits shown in Today that repeat on it.
    var isOtherDay = false
    /// The calendars are readable and chosen: a link to an event that is not found is a problem.
    var eventsKnown = true
}

/// Decides what is in today, what goes to the pool and what goes to the timeline.
struct DayBuilder: Sendable {
    let rules: DayRules
    let sortCriteria: [PoolSortCriterion]

    func build(_ inputs: DayInputs, context: DayContext) -> DayPlan {
        let graph = TaskGraph(tasks: inputs.tasks)
        let occurrence = TaskOccurrence(calendar: context.calendar)
        let resolver = EventLinkResolver(events: inputs.events, calendar: context.calendar)
        let blocking = BlockingEvaluator(graph: graph, occurrence: occurrence, skipped: inputs.skipped, context: context)
        let sorter = PoolSorter(criteria: sortCriteria, rules: rules, routines: inputs.routines)

        var items: [DayItem] = []
        var anchors: [String: TimelineChain.Anchor] = [:]
        var problems: [PlanProblem] = []
        for task in inputs.tasks {
            let previousEvent = task.previousEvent.flatMap(resolver.resolve)
            let nextEvent = task.nextEvent.flatMap(resolver.resolve)
            let inDay = inputs.isOtherDay
                ? isOnOtherDay(task, occurrence: occurrence, context: context)
                : isInDay(task, occurrence: occurrence, skipped: inputs.skipped, context: context)
                && !inputs.postponed.contains(task.name)
            let taskProblems = self.problems(of: task, graph: graph, previousEvent: previousEvent, nextEvent: nextEvent,
                                             checkEvents: inDay && inputs.eventsKnown)
            if inDay || (task.isHabit && !task.isArchived) || !task.status.isCompleted {
                problems += taskProblems.map { PlanProblem(taskName: task.name, problem: $0) }
            }

            guard inDay else { continue }
            let state = self.state(of: task, today: context.today)
            items.append(DayItem(task: task, state: state,
                                 blockers: blocking.blockers(for: task, previousEvent: previousEvent),
                                 problems: taskProblems))
            if let event = previousEvent, overlapsToday(event, context) {
                anchors[task.name] = .after(TimelineChain.Target(event: event))
            } else if let event = nextEvent, overlapsToday(event, context) {
                anchors[task.name] = .before(TimelineChain.Target(event: event))
            }
        }

        let timed = items.filter { inputs.timelineFilter.shows($0) && !timesOfDay(of: $0.task, context: context).isEmpty }
        let shownTimed = timed.filter { !openTimes(of: $0, context: context).isEmpty }
        let timedNames = Set(timed.map(\.id))
        let chainAnchors = propagate(anchors, timed: targets(of: shownTimed, context: context),
                                     through: items.filter { !timedNames.contains($0.id) }, graph: graph)
        // Done today: it leaves the pool and the timeline instead of staying greyed out.
        let poolItems = items.filter { !$0.isFinished && !timedNames.contains($0.id) && chainAnchors[$0.id] == nil }

        let pool = SubtaskNesting.nested(inputs.manualOrder.map { sorter.applyingManualOrder($0, to: poolItems, graph: graph, context: context) }
            ?? sorter.sorted(poolItems, graph: graph, context: context))

        var timeline = fixedEntries(timed: shownTimed, events: inputs.timelineFilter.events ? inputs.events : [],
                                    reminders: inputs.timelineFilter.reminders ? inputs.reminders : [], context: context)
        let chainLayout = ChainLayout(rules: rules)
        for chain in chains(items: items, anchors: chainAnchors, sorter: sorter, graph: graph, context: context) {
            timeline += chainLayout.entries(for: chain, now: context.focus)
        }
        timeline.sort { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }

        let allDay = inputs.events.filter { $0.isAllDay && $0.covers(context.today, calendar: context.calendar) }
            .sorted { $0.title < $1.title }
        var plan = DayPlan(today: context.today, now: context.now, pool: pool, timeline: timeline, problems: problems, allDayEvents: allDay)
        plan.focus = context.focus
        return plan
    }

    // MARK: - Membership

    private func isInDay(_ task: TaskNote, occurrence: TaskOccurrence, skipped: Set<String>, context: DayContext) -> Bool {
        if task.isHabit {
            guard task.isInTodayHabits, !skipped.contains(task.name) else { return false }
            return occurrence.occurs(task, on: context.today) || HabitInstances(task: task).mark(on: context.today) != nil
        }
        return (task.status == .thisWeek && !isDatedLater(task, context: context))
            || (task.status == .done && task.completedDate == context.today)
    }

    /// A task dated after today (Tomorrow, a day of next week) waits for its day, even this week.
    /// An overdue one stays in today.
    private func isDatedLater(_ task: TaskNote, context: DayContext) -> Bool {
        guard let due = task.due else { return false }
        return context.logicalDay(of: due) > context.today
    }

    private func isOnOtherDay(_ task: TaskNote, occurrence: TaskOccurrence, context: DayContext) -> Bool {
        if task.isHabit { return task.isInTodayHabits && occurrence.occurs(task, on: context.today) }
        guard task.status == .thisWeek, let due = task.due else { return false }
        return context.logicalDay(of: due) == context.today
    }

    private func state(of task: TaskNote, today: LocalDate) -> DayItemState {
        if task.isHabit {
            return HabitInstances(task: task).mark(on: today).map(DayItemState.marked) ?? .open
        }
        return task.status == .done ? .marked(.done) : .open
    }

    /// Habits are planned at their reminder times; other tasks need `due` with a time on today's logical day.
    private func timesOfDay(of task: TaskNote, context: DayContext) -> [LocalTime] {
        if task.isHabit { return task.habitTimes }
        guard let due = task.due, let time = due.time, context.logicalDay(of: due) == context.today else { return [] }
        return [time]
    }

    /// The times still to do today. Done leaves the timeline; a habit with several reminders loses one block per
    /// mark, earliest first (Done the first of two, Twice both); one with a single time keeps it until the day
    /// is closed (twice a day waits for Twice).
    private func openTimes(of item: DayItem, context: DayContext) -> [LocalTime] {
        let times = timesOfDay(of: item.task, context: context)
        guard item.isHabit, times.count > 1 else { return item.isFinished ? [] : times }
        let ordered = times.sorted { context.moment($0, onLogicalDay: context.today) < context.moment($1, onLogicalDay: context.today) }
        return Array(ordered.dropFirst(HabitMarking.timesClosed(by: item.state.mark)))
    }

    private func overlapsToday(_ event: CalendarEvent, _ context: DayContext) -> Bool {
        event.start < context.dayEnd && event.end > context.dayStart
    }

    /// Problems of done/archived tasks are not reported (see `build`); event links are checked only
    /// for tasks in the day, since only today's events are looked up around it.
    private func problems(of task: TaskNote, graph: TaskGraph, previousEvent: CalendarEvent?, nextEvent: CalendarEvent?,
                          checkEvents: Bool) -> [TaskProblem] {
        var result = task.problems
        result += (graph.missingLinks[task.name] ?? []).map(TaskProblem.linkedTaskNotFound)
        if graph.cycleMembers.contains(task.name) { result.append(.dependencyCycle) }
        guard checkEvents else { return result }
        if let link = task.previousEvent, previousEvent == nil { result.append(.eventNotFound(link.title)) }
        if let link = task.nextEvent, nextEvent == nil { result.append(.eventNotFound(link.title)) }
        return result
    }

    // MARK: - Timeline

    /// Anything linked to the timeline, directly or not, goes there too; only tasks linked among the pool
    /// alone stay in the pool. A task after an event or a timed task (or after a task that is) follows it; a task
    /// that must be done before one of them is laid out from now.
    private func propagate(_ anchors: [String: TimelineChain.Anchor], timed: [String: TimelineChain.Target],
                           through items: [DayItem], graph: TaskGraph) -> [String: TimelineChain.Anchor] {
        var result: [String: TimelineChain.Anchor] = [:]
        let ordered = TopologicalOrder.stable(items.sorted { $0.id < $1.id }, graph: graph)
        func target(of name: String) -> TimelineChain.Target? { timed[name] ?? result[name]?.target }
        var changed = true
        while changed {
            changed = false
            for item in ordered where result[item.id] == nil {
                let followed = graph.predecessors(of: item.id).lazy.compactMap { timed[$0].map(TimelineChain.Anchor.after) ?? result[$0] }.first
                if let anchor = anchors[item.id] ?? followed {
                    result[item.id] = anchor
                    changed = true
                }
            }
            for item in ordered.reversed() where result[item.id] == nil {
                if let next = graph.successors(of: item.id).lazy.compactMap(target(of:)).first {
                    result[item.id] = .before(next)
                    changed = true
                }
            }
        }
        return result
    }

    /// Timed tasks and habits as chain targets: their first open block today.
    private func targets(of timed: [DayItem], context: DayContext) -> [String: TimelineChain.Target] {
        var result: [String: TimelineChain.Target] = [:]
        for item in timed {
            guard let time = openTimes(of: item, context: context).first else { continue }
            let start = context.moment(time, onLogicalDay: context.today)
            result[item.id] = TimelineChain.Target(id: "task:\(item.id)", end: start.addingTimeInterval(Double(rules.estimate(of: item.task)) * 60))
        }
        return result
    }

    private func chains(items: [DayItem], anchors: [String: TimelineChain.Anchor], sorter: PoolSorter,
                        graph: TaskGraph, context: DayContext) -> [TimelineChain] {
        var groups: [String: (anchor: TimelineChain.Anchor, items: [DayItem])] = [:]
        for item in items {
            guard let anchor = anchors[item.id] else { continue }
            groups[anchor.key, default: (anchor, [])].items.append(item)
        }
        return groups.keys.sorted().compactMap { key in
            guard let group = groups[key] else { return nil }
            return TimelineChain(anchor: group.anchor, items: sorter.sorted(group.items, graph: graph, context: context))
        }
    }

    private func fixedEntries(timed: [DayItem], events: [CalendarEvent], reminders: [ReminderItem], context: DayContext) -> [TimelineSlot] {
        var entries: [TimelineSlot] = []
        for event in events where !event.isAllDay && overlapsToday(event, context) {
            entries.append(TimelineSlot(content: .event(event), start: event.start, end: event.end, isPast: event.end <= context.now,
                                        alerts: event.hasAlarm))
        }
        for item in timed {
            for time in openTimes(of: item, context: context) {
                let start = context.moment(time, onLogicalDay: context.today)
                let end = start.addingTimeInterval(Double(rules.estimate(of: item.task)) * 60)
                entries.append(TimelineSlot(content: .task(item), start: start, end: end, isPast: false, time: time, alerts: true))
            }
        }
        for reminder in reminders where context.contains(reminder.due) && !reminder.isCompleted {
            let end = reminder.due.addingTimeInterval(Double(rules.reminderMinutes) * 60)
            entries.append(TimelineSlot(content: .reminder(reminder), start: reminder.due, end: end, isPast: false, alerts: true))
        }
        return entries
    }
}
