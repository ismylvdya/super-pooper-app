import Foundation

/// Decides what still holds a task back today.
struct BlockingEvaluator: Sendable {
    let graph: TaskGraph
    let occurrence: TaskOccurrence
    let skipped: Set<String>
    let context: DayContext

    func blockers(for task: TaskNote, previousEvent: CalendarEvent?) -> [Blocker] {
        var result = graph.predecessors(of: task.name)
            .filter { !isSatisfied($0) }
            .map(Blocker.task)
        if let event = previousEvent, event.end > context.now {
            result.append(.event(title: event.title, end: event.end))
        }
        return result
    }

    /// A predecessor is satisfied when it is done; a recurring one — when today is marked or skipped,
    /// or when it has no instance today at all.
    func isSatisfied(_ name: String) -> Bool {
        guard let task = graph.tasksByName[name] else { return true }
        guard task.isHabit else { return task.status.isCompleted }
        if skipped.contains(name) { return true }
        if HabitInstances(task: task).mark(on: context.today) != nil { return true }
        return !occurrence.occurs(task, on: context.today)
    }
}
