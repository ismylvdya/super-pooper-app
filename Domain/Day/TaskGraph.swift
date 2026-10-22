import Foundation

/// The `previous_task` links between tasks, resolved by name, with cycles broken.
struct TaskGraph: Sendable {
    let tasksByName: [String: TaskNote]
    /// Resolved predecessors per task (edges that closed a cycle are dropped).
    let predecessors: [String: [String]]
    let successors: [String: [String]]
    let missingLinks: [String: [String]]
    let cycleMembers: Set<String>

    init(tasks: [TaskNote]) {
        let byName = Dictionary(tasks.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let byLowercased = Dictionary(tasks.map { ($0.name.lowercased(), $0.name) }, uniquingKeysWith: { first, _ in first })

        var resolved: [String: [String]] = [:]
        var missing: [String: [String]] = [:]
        for task in tasks {
            for link in task.previousTasks {
                guard let name = byName[link]?.name ?? byLowercased[link.lowercased()] else {
                    missing[task.name, default: []].append(link)
                    continue
                }
                if name != task.name, resolved[task.name, default: []].contains(name) == false {
                    resolved[task.name, default: []].append(name)
                }
            }
        }

        let (acyclic, cycleMembers) = TaskGraph.breakCycles(resolved, order: tasks.map(\.name).sorted())
        var successors: [String: [String]] = [:]
        for (task, preds) in acyclic {
            for pred in preds { successors[pred, default: []].append(task) }
        }
        self.tasksByName = byName
        self.predecessors = acyclic
        self.successors = successors.mapValues { $0.sorted() }
        self.missingLinks = missing
        self.cycleMembers = cycleMembers
    }

    func predecessors(of name: String) -> [String] { predecessors[name] ?? [] }
    func successors(of name: String) -> [String] { successors[name] ?? [] }

    /// Depth-first search that drops back edges; every node on a found cycle is reported.
    private static func breakCycles(_ edges: [String: [String]], order: [String]) -> ([String: [String]], Set<String>) {
        var result = edges
        var members = Set<String>()
        var visited = Set<String>()
        var stack: [String] = []
        var onStack = Set<String>()

        func visit(_ node: String) {
            visited.insert(node)
            stack.append(node)
            onStack.insert(node)
            for next in edges[node] ?? [] {
                if onStack.contains(next) {
                    result[node]?.removeAll { $0 == next }
                    if let start = stack.firstIndex(of: next) { members.formUnion(stack[start...]) }
                } else if !visited.contains(next) {
                    visit(next)
                }
            }
            stack.removeLast()
            onStack.remove(node)
        }

        for node in order where !visited.contains(node) { visit(node) }
        return (result.filter { !$0.value.isEmpty }, members)
    }
}
