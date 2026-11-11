import Foundation

/// A task shown one step at a time (`TaskItem.stepsOneByOne`, "Show one at a time"): of everything under it only the
/// next action is up — its first open subtask, or that one's first open subtask, all the way down. The pool shows that
/// one alone, with the name of the task on top over it (`projectOf`); the task itself and its other subtasks stay out
/// of the pool, and those other subtasks out of the lists too, until the steps before them are done. A task inside
/// another shown one at a time follows the one on top.
enum TaskSteps {
    struct Plan: Equatable, Sendable {
        /// The subtasks waiting for an earlier step.
        var waiting: Set<String> = []
        /// The tasks on top, shown through their next action.
        var projects: Set<String> = []
        /// Each next action's task on top.
        var projectOf: [String: String] = [:]
    }

    static func plan(in tasks: [TaskItem]) -> Plan {
        let index = Index(tasks)
        var plan = Plan()
        for project in tasks where isProject(project) && !index.ancestors(of: project).contains(where: isProject) {
            plan.projects.insert(project.name)
            let next = nextStep(of: project, index: index)
            if let next { plan.projectOf[next.name] = project.name }
            plan.waiting.formUnion(index.descendants(of: project).subtracting(next.map { [$0.name] } ?? []))
        }
        return plan
    }

    /// The subtasks waiting for an earlier step.
    static func waiting(in tasks: [TaskItem]) -> Set<String> { plan(in: tasks).waiting }

    /// The next action of a task shown one at a time: its first open subtask in their order, down to one with none open.
    static func nextStep(of project: TaskItem, in tasks: [TaskItem]) -> TaskItem? {
        nextStep(of: project, index: Index(tasks))
    }

    /// A step just done: the next one of its task on top is up from tomorrow, not today — it comes in the next morning's
    /// review. Nil when there is no next one, or it stands on a later day already.
    static func afterDone(_ done: TaskItem, in tasks: [TaskItem], tomorrow: LocalDate) -> (name: String, edits: [TaskEdit])? {
        let index = Index(tasks)
        guard let project = ([done] + index.ancestors(of: done)).last(where: isProject), project.name != done.name,
              let next = nextStep(of: project, index: index) else { return nil }
        if let day = next.due?.day, day >= tomorrow { return nil }
        var edits: [TaskEdit] = next.status.isThisWeek ? [] : [.status(.thisWeek)]
        edits.append(.due(TaskDue(day: tomorrow)))
        return (next.name, edits)
    }

    private static func isProject(_ task: TaskItem) -> Bool {
        task.stepsOneByOne && !task.isHabit && !task.status.isCompleted
    }

    private static func nextStep(of task: TaskItem, index: Index) -> TaskItem? {
        for child in index.openChildren(of: task) {
            return nextStep(of: child, index: index) ?? child
        }
        return nil
    }

    /// Who stands under whom, by the parents the tasks name.
    private struct Index {
        let byName: [NoteName: TaskItem]
        let children: [NoteName: [TaskItem]]

        init(_ tasks: [TaskItem]) {
            byName = Dictionary(tasks.map { ($0.name.noteName, $0) }, uniquingKeysWith: { first, _ in first })
            children = Dictionary(grouping: tasks.filter { $0.projects.first != nil }) { $0.projects[0].noteName }
        }

        func openChildren(of task: TaskItem) -> [TaskItem] {
            (children[task.name.noteName] ?? []).filter { !$0.status.isCompleted }.sorted { first, second in
                switch (first.subtaskOrder, second.subtaskOrder) {
                case let (one?, other?) where one != other: one < other
                default: (first.storeOrder ?? 0) < (second.storeOrder ?? 0)
                }
            }
        }

        func ancestors(of task: TaskItem) -> [TaskItem] {
            var found: [TaskItem] = []
            var next = task.projects.first.flatMap { byName[$0.noteName] }
            while let parent = next, !found.contains(where: { $0.name == parent.name }), parent.name != task.name {
                found.append(parent)
                next = parent.projects.first.flatMap { byName[$0.noteName] }
            }
            return found
        }

        func descendants(of task: TaskItem) -> Set<String> {
            var found: Set<String> = []
            var queue = openChildren(of: task)
            while let next = queue.popLast() {
                guard found.insert(next.name).inserted else { continue }
                queue += openChildren(of: next)
            }
            return found
        }
    }
}
