import Foundation

/// The projects of the Lists page: parents marked to be shown as projects (`TaskItem.showsAsProject`), open ones, by
/// name, each with how many open tasks it holds all the way down.
enum ProjectList {
    static func projects(in tasks: [TaskItem]) -> [TaskItem] {
        NameOrder.sorted(tasks.filter { $0.showsAsProject && !$0.status.isCompleted })
    }

    static func openCount(of project: TaskItem, in tasks: [TaskItem]) -> Int {
        let children = Dictionary(grouping: tasks.filter { !$0.status.isCompleted && $0.projects.first != nil }) { $0.projects[0].noteName }
        var seen: Set<NoteName> = [project.name.noteName]
        var queue = children[project.name.noteName] ?? []
        var count = 0
        while let next = queue.popLast() {
            guard seen.insert(next.name.noteName).inserted else { continue }
            count += 1
            queue += children[next.name.noteName] ?? []
        }
        return count
    }
}
