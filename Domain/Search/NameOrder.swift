import Foundation

/// The one order of notes by name wherever they are listed (search, pickers, links, archives): the way
/// Finder sorts, ignoring case and reading numbers as numbers, so "Task 2" comes before "Task 10".
enum NameOrder {
    static func precedes(_ first: String, _ second: String) -> Bool {
        first.localizedStandardCompare(second) == .orderedAscending
    }

    static func sorted(_ names: [String]) -> [String] {
        names.sorted(by: precedes)
    }

    static func sorted(_ tasks: [TaskNote]) -> [TaskNote] {
        tasks.sorted { precedes($0.name, $1.name) }
    }
}
