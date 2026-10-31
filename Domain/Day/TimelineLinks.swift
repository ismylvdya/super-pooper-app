import Foundation

/// Links between the blocks of a timeline: previous tasks between tasks, the event before or after a task between a
/// task and an event. Used to badge linked blocks and to highlight everything connected to one. An event
/// link finds its event as the day does (`EventLinkResolver`: the identifier on that day, else the title and start).
struct TimelineLinks: Sendable {
    /// Slot id → ids of the slots it is directly linked to.
    let neighbors: [String: Set<String>]

    init(slots: [TimelineSlot], calendar: Calendar) {
        var taskSlots: [NoteName: [String]] = [:]
        var eventSlots: [String: [String]] = [:]
        var events: [CalendarEvent] = []
        for slot in slots {
            switch slot.content {
            case .task(let item): taskSlots[item.task.name.noteName, default: []].append(slot.id)
            case .event(let event):
                eventSlots[event.id, default: []].append(slot.id)
                events.append(event)
            case .reminder: break
            }
        }
        let resolver = EventLinkResolver(events: events, calendar: calendar)
        var neighbors: [String: Set<String>] = [:]
        func link(_ ids: [String], _ others: [String]) {
            for id in ids {
                for other in others where other != id {
                    neighbors[id, default: []].insert(other)
                    neighbors[other, default: []].insert(id)
                }
            }
        }
        for slot in slots {
            guard case .task(let item) = slot.content else { continue }
            for name in item.task.previousTasks { link([slot.id], taskSlots[name.noteName] ?? []) }
            for event in [item.task.previousEvent, item.task.nextEvent].compactMap({ $0 }).compactMap(resolver.resolve) {
                link([slot.id], eventSlots[event.id] ?? [])
            }
        }
        self.neighbors = neighbors
    }

    func isLinked(_ id: String) -> Bool { !(neighbors[id]?.isEmpty ?? true) }

    /// Everything reachable from `id` through links, `id` included.
    func connected(to id: String) -> Set<String> {
        var result: Set<String> = [id]
        var queue = [id]
        while let current = queue.popLast() {
            for next in neighbors[current] ?? [] where result.insert(next).inserted { queue.append(next) }
        }
        return result
    }
}
