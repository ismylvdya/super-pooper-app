import Foundation

/// A project done step by step (`TaskItem.stepsOneByOne`): of its open subtasks, in their order, only the first is up
/// to do. The others wait, with what stands under them, and stay out of the day and the lists until the steps before
/// them are done; on the parent's page they are shown as later steps.
enum TaskSteps {
    /// The names of the tasks waiting for an earlier step.
    static func waiting(in tasks: [TaskItem]) -> Set<String> {
        var waiting: Set<String> = []
        for parent in tasks where parent.stepsOneByOne && !parent.isHabit && !parent.status.isCompleted {
            for step in steps(of: parent, in: tasks).dropFirst() {
                waiting.insert(step.name)
                waiting.formUnion(descendants(of: step, in: tasks))
            }
        }
        return waiting
    }

    /// The parent's open subtasks in their order (`subtaskOrder`, then the store's).
    static func steps(of parent: TaskItem, in tasks: [TaskItem]) -> [TaskItem] {
        children(of: parent, in: tasks).filter { !$0.status.isCompleted }.sorted { first, second in
            switch (first.subtaskOrder, second.subtaskOrder) {
            case let (one?, other?) where one != other: one < other
            default: (first.storeOrder ?? 0) < (second.storeOrder ?? 0)
            }
        }
    }

    private static func children(of parent: TaskItem, in tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { $0.projects.first?.isSameNoteName(as: parent.name) == true }
    }

    private static func descendants(of task: TaskItem, in tasks: [TaskItem]) -> Set<String> {
        var found: Set<String> = []
        var queue = [task]
        while let next = queue.popLast() {
            for child in children(of: next, in: tasks) where !found.contains(child.name) {
                found.insert(child.name)
                queue.append(child)
            }
        }
        return found
    }
}
