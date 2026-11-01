import Foundation

/// Anything linked to the timeline, directly or not, goes there too; only tasks linked among the pool alone stay in the
/// pool. A task after an event or a timed task (or after a task that is) follows it; a task that must be done before
/// one of them is laid out from now.
enum ChainAnchors {
    /// `anchors`: the tasks' own event links; `timed`: the timed tasks and habits as targets.
    static func propagate(_ anchors: [String: TimelineChain.Anchor], timed: [String: TimelineChain.Target],
                          through items: [DayItem], graph: TaskGraph) -> [String: TimelineChain.Anchor] {
        var result: [String: TimelineChain.Anchor] = [:]
        let ordered = TopologicalOrder.stable(items.sorted { $0.id < $1.id }, graph: graph)
        func target(of name: String) -> TimelineChain.Target? { timed[name] ?? result[name]?.target }
        var changed = true
        while changed {
            changed = false
            for item in ordered where result[item.id] == nil {
                let followed = graph.predecessors(of: item.id).lazy.compactMap { timed[$0].map(TimelineChain.Anchor.after) ?? result[$0] }.first
                if let anchor = anchors[item.id] ?? followed {
                    result[item.id] = anchor
                    changed = true
                }
            }
            for item in ordered.reversed() where result[item.id] == nil {
                if let next = graph.successors(of: item.id).lazy.compactMap(target(of:)).first {
                    result[item.id] = .before(next)
                    changed = true
                }
            }
        }
        return result
    }

    /// The tasks of each anchor as one chain, in link-and-sort order; chains in the order of their anchors.
    static func chains(items: [DayItem], anchors: [String: TimelineChain.Anchor], sorter: PoolSorter,
                       graph: TaskGraph, context: DayContext) -> [TimelineChain] {
        var groups: [String: (anchor: TimelineChain.Anchor, items: [DayItem])] = [:]
        for item in items {
            guard let anchor = anchors[item.id] else { continue }
            groups[anchor.key, default: (anchor, [])].items.append(item)
        }
        return groups.keys.sorted().compactMap { key in
            guard let group = groups[key] else { return nil }
            return TimelineChain(anchor: group.anchor, items: sorter.sorted(group.items, graph: graph, context: context))
        }
    }
}
