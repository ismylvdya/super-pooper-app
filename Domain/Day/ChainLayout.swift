import Foundation

/// Places the open chain tasks one after another from the cursor, so they slide along with "now" during the day.
struct ChainLayout: Sendable {
    let rules: DayRules

    func entries(for chain: TimelineChain, now: Date) -> [TimelineSlot] {
        let origin: Date
        switch chain.anchor {
        case .before: origin = now
        case .after(let target): origin = max(target.end, now)
        }

        var entries: [TimelineSlot] = []
        var cursor = origin
        for item in chain.items where !item.isFinished {
            let end = cursor.addingTimeInterval(rules.duration(of: item.task))
            entries.append(TimelineSlot(content: .task(item), start: cursor, end: end, isPast: false))
            cursor = end
        }
        return entries
    }
}
