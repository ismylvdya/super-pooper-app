import Foundation

/// The tasks and habits a note can be linked to (its Previous and Next tasks): any not archived, except `excluded`
/// (the note itself and its links already, by note name: letter case does not matter), whose names contain the query,
/// in name order.
enum LinkCandidates {
    static func tasks(_ tasks: [TaskItem], excluding excluded: Set<String>, matching query: String) -> [TaskItem] {
        let excludedNames = Set(excluded.map(\.noteName))
        return NameOrder.sorted(tasks.filter {
            !excludedNames.contains($0.name.noteName) && $0.isLinkable && SearchMatcher.matches($0.name, query)
        })
    }
}
