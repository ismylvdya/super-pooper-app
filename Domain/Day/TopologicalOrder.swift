import Foundation

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
