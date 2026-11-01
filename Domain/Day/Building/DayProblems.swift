import Foundation

/// What is wrong with a task's data and links. Event links are checked only for tasks in the day, since only today's
/// events are looked up around it.
struct DayProblems: Sendable {
    let graph: TaskGraph
    let occurrence: TaskOccurrence

    func problems(of task: TaskItem, previousEvent: CalendarEvent?, nextEvent: CalendarEvent?, checkEvents: Bool) -> [TaskProblem] {
        var result = task.problems
        if occurrence.hasNoStart(task) { result.append(.recurrenceWithoutStart) }
        result += (graph.missingLinks[task.name] ?? []).map(TaskProblem.linkedTaskNotFound)
        if graph.cycleMembers.contains(task.name) { result.append(.dependencyCycle) }
        guard checkEvents else { return result }
        if let link = task.previousEvent, previousEvent == nil { result.append(.eventNotFound(link.title)) }
        if let link = task.nextEvent, nextEvent == nil { result.append(.eventNotFound(link.title)) }
        return result
    }
}
