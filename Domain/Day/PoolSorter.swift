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
        let byName = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result = manual.compactMap { byName[$0] }
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

    private func key(_ criterion: PoolSortCriterion, _ task: TaskNote, _ context: DayContext) -> Double {
        switch criterion {
        case .morningRoutine:
            return task.isHabit && task.habit.timeOfDay == .morning ? 0 : 1
        case .routineOrder:
            return routines.position(of: task).map(Double.init) ?? 10_000
        case .habitsFirst:
            return task.isHabit && task.habitTimes.isEmpty ? 0 : 1
        case .habitTimeOfDay:
            guard task.isHabit, let part = task.habit.timeOfDay else { return 1 }
            return part == rules.partOfDay(context) ? 0 : 2
        case .dueToday:
            return !task.isHabit && task.due.map(context.logicalDay(of:)) == context.today ? 0 : 1
        case .highPriority:
            return task.isHighPriority ? 0 : 1
        case .nearestDueThisWeek:
            guard !task.isHabit, let day = task.due.map(context.logicalDay(of:)), day >= context.today, day <= context.weekEnd else { return 1_000 }
            return Double(context.today.days(until: day))
        case .energyBeforeEnergyHour:
            guard task.needEnergy else { return 1 }
            return context.isBeforeEnergyHour ? 0 : 2
        case .unpleasantFirst:
            return task.pleasant == false ? 0 : 1
        case .shortFirst:
            return Double(rules.estimate(of: task))
        case .olderFirst:
            return task.dateCreated?.timeIntervalSince1970 ?? .greatestFiniteMagnitude
        }
    }
}
