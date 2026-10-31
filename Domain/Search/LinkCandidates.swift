import Foundation

/// The tasks and habits a note can be linked to (its Previous and Next tasks): any not archived, except `excluded`
/// (the note itself and its links already), whose names contain the query, in name order.
enum LinkCandidates {
    static func tasks(_ tasks: [TaskItem], excluding excluded: Set<String>, matching query: String) -> [TaskItem] {
        NameOrder.sorted(tasks.filter { !excluded.contains($0.name) && $0.isLinkable && SearchMatcher.matches($0.name, query) })
    }
}
