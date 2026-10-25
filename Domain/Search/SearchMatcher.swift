import Foundation

/// Case-insensitive "contains" over names and titles; the order is `NameOrder` for tasks, by time for events.
enum SearchMatcher {
    static func tasks(_ tasks: [TaskNote], matching query: String) -> [TaskNote] {
        guard !query.isEmpty else { return [] }
        return NameOrder.sorted(tasks.filter { matches($0.name, query) })
    }

    static func events(_ events: [CalendarEvent], matching query: String) -> [CalendarEvent] {
        guard !query.isEmpty else { return [] }
        return events.filter { matches($0.title, query) }.sorted { $0.start < $1.start }
    }

    /// An empty query matches everything (a picker shows all before the user types).
    static func matches(_ text: String, _ query: String) -> Bool {
        query.isEmpty || text.localizedCaseInsensitiveContains(query)
    }
}

