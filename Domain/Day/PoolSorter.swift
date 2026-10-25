import Foundation

/// Pool ordering criteria, compared one after another (order comes from `sort.json`).
enum PoolSortCriterion: String, Codable, CaseIterable, Sendable {
    /// The morning routine (habits of the morning) goes above everything.
    case morningRoutine
    /// Recurring tasks without a time go first.
    case habitsFirst
    /// Habits of the current part of the day go up, habits of another part go down.
    case habitTimeOfDay
    /// Within the morning and evening routines, the user's routine order.
    case routineOrder
    /// `due` today (with or without time) beats everything below.
    case dueToday
    case highPriority
    /// The nearest `due` within this week goes earlier.
    case nearestDueThisWeek
    /// `need_energy` tasks go up before the energy hour and down after it.
    case energyBeforeEnergyHour
    /// `pleasant: false` before the rest.
    case unpleasantFirst
    /// Shorter `time_estimate` first.
    case shortFirst
    /// Older `date_created` first.
    case olderFirst
}

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

/// Kahn's algorithm that always takes the earliest available item, so the input order
/// survives wherever the links allow.
enum TopologicalOrder {
    static func stable(_ items: [DayItem], graph: TaskGraph) -> [DayItem] {
        let names = Set(items.map(\.id))
        var remaining = items
        var emitted = Set<String>()
        var result: [DayItem] = []
        while !remaining.isEmpty {
            let index = remaining.firstIndex { item in
                graph.predecessors(of: item.id).allSatisfy { !names.contains($0) || emitted.contains($0) }
            } ?? 0
            let item = remaining.remove(at: index)
            emitted.insert(item.id)
            result.append(item)
        }
        return result
    }
}
