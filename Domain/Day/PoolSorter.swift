import Foundation

/// Orders tasks: criteria from config, then "never above its predecessors", then done ones last.
struct PoolSorter: Sendable {
    let criteria: [PoolSortCriterion]
    let rules: DayRules
    var routines = HabitRoutines()

    func sorted(_ items: [DayItem], graph: TaskGraph, context: DayContext) -> [DayItem] {
        let auto = items.sorted { lhs, rhs in
            for criterion in criteria {
                let left = key(criterion, lhs.task, context)
                let right = key(criterion, rhs.task, context)
                if left != right { return left < right }
            }
            return NameOrder.precedes(lhs.task.name, rhs.task.name)
        }
        return finalize(auto, graph: graph)
    }

    /// Keeps the user's order for known tasks; tasks that appeared later are inserted
    /// right after their auto-sorted neighbour.
    func applyingManualOrder(_ manual: [String], to items: [DayItem], graph: TaskGraph, context: DayContext) -> [DayItem] {
        let auto = sorted(items, graph: graph, context: context)
        let byName = Dictionary(items.map { ($0.id.noteName, $0) }, uniquingKeysWith: { first, _ in first })
        var result = manual.compactMap { byName[$0.noteName] }
        let placed = Set(result.map(\.id))
        for (index, item) in auto.enumerated() where !placed.contains(item.id) {
            let previous = auto[..<index].last { result.contains($0) }
            let position = previous.flatMap { prev in result.firstIndex { $0.id == prev.id } }.map { $0 + 1 } ?? 0
            result.insert(item, at: position)
        }
        return finalize(result, graph: graph)
    }

    /// Done tasks go last; within each part a task never stands above its predecessors.
    private func finalize(_ items: [DayItem], graph: TaskGraph) -> [DayItem] {
        let open = TopologicalOrder.stable(items.filter { !$0.isDone }, graph: graph)
        let done = TopologicalOrder.stable(items.filter(\.isDone), graph: graph)
        return open + done
    }

    /// A criterion's place for a task; a task the criterion knows nothing about (no routine place, no due date this week,
    /// no creation date) comes after every task it knows.
    private enum SortKey: Comparable {
        case known(Double)
        case unknown
    }

    private func key(_ criterion: PoolSortCriterion, _ task: TaskItem, _ context: DayContext) -> SortKey {
        switch criterion {
        case .morningRoutine:
            return .known(task.habit.timeOfDay == .morning ? 0 : 1)
        case .routineOrder:
            return routines.position(of: task).map { .known(Double($0)) } ?? .unknown
        case .habitsFirst:
            return .known(task.isHabit && task.habitTimes.isEmpty ? 0 : 1)
        case .habitTimeOfDay:
            guard let part = task.habit.timeOfDay else { return .known(1) }
            return .known(part == rules.partOfDay(context) ? 0 : 2)
        case .dueToday:
            return .known(!task.isHabit && task.due.map(context.logicalDay(of:)) == context.today ? 0 : 1)
        case .highPriority:
            return .known(task.isHighPriority ? 0 : 1)
        case .nearestDueThisWeek:
            guard !task.isHabit, let day = task.due.map(context.logicalDay(of:)), day >= context.today, day <= context.weekEnd else { return .unknown }
            return .known(Double(context.today.days(until: day)))
        case .energyBeforeEnergyHour:
            guard task.feel == .needEnergy else { return .known(1) }
            return .known(context.isBeforeEnergyHour ? 0 : 2)
        case .unpleasantFirst:
            // Pleasant tasks are a reward: they wait for the rest.
            return .known(task.feel == .pleasant ? 1 : 0)
        case .shortFirst:
            return .known(Double(rules.estimate(of: task)))
        case .olderFirst:
            return task.dateCreated.map { .known($0.timeIntervalSince1970) } ?? .unknown
        }
    }
}
