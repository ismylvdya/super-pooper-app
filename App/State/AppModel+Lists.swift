import Foundation

/// Projects: parents shown on the Lists page under Projects (`ProjectList`), and the steps of the ones done step by step.
extension AppModel {
    /// The later steps of projects done step by step: they wait for the steps before them (`TaskSteps`).
    var waitingSteps: Set<String> { TaskSteps.waiting(in: tasks) }

    /// The parents shown as projects, by name.
    var projects: [TaskItem] { ProjectList.projects(in: tasks) }

    /// How many open tasks a project holds, all the way down.
    func openTaskCount(of project: TaskItem) -> Int { ProjectList.openCount(of: project, in: tasks) }
}
