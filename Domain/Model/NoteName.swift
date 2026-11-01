import Foundation

/// A note's identity by its name, the one rule for every place that finds a note by name (links, subtasks, the habit
/// order, routines, Skip today, Not today, the pool order): names match like Obsidian links on Apple platforms, where
/// the file system ignores letter case. Swift strings already compare any Unicode form of a letter alike.
struct NoteName: Hashable, Sendable {
    private let key: String

    init(_ name: String) {
        key = name.lowercased()
    }
}

extension String {
    var noteName: NoteName { NoteName(self) }

    func isSameNoteName(as other: String) -> Bool {
        noteName == other.noteName
    }
}

extension Sequence<String> {
    /// The list names this note (in any letter case).
    func containsNoteName(_ name: String) -> Bool {
        let wanted = name.noteName
        return contains { $0.noteName == wanted }
    }
}
