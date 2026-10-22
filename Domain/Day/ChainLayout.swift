import Foundation

/// Tasks tied to a calendar event, directly or through their predecessors.
struct TimelineChain: Sendable {
    enum Anchor: Sendable {
        /// `next_event`: done before the event, laid out from "now".
        case before(CalendarEvent)
        /// `previous_event`: done after the event, laid out from its end (or "now" if it is over).
        case after(CalendarEvent)
    }

    let anchor: Anchor
    /// Already in link-and-sort order.
    let items: [DayItem]
}

/// Places chain tasks one after another. Open tasks follow the cursor (so they slide along
/// with "now" during the day); done ones are stacked right before it.
struct ChainLayout: Sendable {
    let rules: DayRules

    func entries(for chain: TimelineChain, now: Date) -> [TimelineSlot] {
        let origin: Date
        switch chain.anchor {
        case .before: origin = now
        case .after(let event): origin = max(event.end, now)
        }

        var entries: [TimelineSlot] = []
        var cursor = origin
        for item in chain.items where !item.isDone {
            let end = cursor.addingTimeInterval(duration(of: item))
            entries.append(TimelineSlot(content: .task(item), start: cursor, end: end, isPast: false))
            cursor = end
        }

        var backCursor = origin
        for item in chain.items.reversed() where item.isDone {
            let start = backCursor.addingTimeInterval(-duration(of: item))
            entries.append(TimelineSlot(content: .task(item), start: start, end: backCursor, isPast: true))
            backCursor = start
        }
        return entries.sorted { $0.start < $1.start }
    }

    private func duration(of item: DayItem) -> TimeInterval {
        Double(rules.estimate(of: item.task)) * 60
    }
}
