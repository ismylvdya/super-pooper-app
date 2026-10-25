import Foundation

/// Tasks tied to something on the timeline — an event or a task with its own time — directly or through links.
struct TimelineChain: Sendable {
    /// What a chain hangs on.
    struct Target: Hashable, Sendable {
        let id: String
        let end: Date

        init(id: String, end: Date) {
            self.id = id
            self.end = end
        }

        init(event: CalendarEvent) {
            self.init(id: "event:\(event.id)", end: event.end)
        }
    }

    enum Anchor: Hashable, Sendable {
        /// Done before it (`next_event`, or a task it leads to): laid out from "now".
        case before(Target)
        /// Done after it (`previous_event`, or a task it follows): laid out from its end (or "now" if it is over).
        case after(Target)

        var target: Target {
            switch self {
            case .before(let target), .after(let target): target
            }
        }

        var key: String {
            switch self {
            case .before(let target): "before:\(target.id)"
            case .after(let target): "after:\(target.id)"
            }
        }
    }

    let anchor: Anchor
    /// Already in link-and-sort order.
    let items: [DayItem]
}

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
            let end = cursor.addingTimeInterval(duration(of: item))
            entries.append(TimelineSlot(content: .task(item), start: cursor, end: end, isPast: false))
            cursor = end
        }
        return entries
    }

    private func duration(of item: DayItem) -> TimeInterval {
        Double(rules.estimate(of: item.task)) * 60
    }
}
