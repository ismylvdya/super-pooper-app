import Foundation

/// The user's own lists (`TaskStatus.custom`): which there are, and the title a new one may take.
enum CustomLists {
    /// The store's lists in its order, then any a task stands in that the store has not got yet (written a moment ago).
    static func titles(stored: [String], tasks: [TaskItem]) -> [String] {
        var titles = stored
        for task in tasks {
            if let title = task.status.customList, !titles.contains(title) { titles.append(title) }
        }
        return titles
    }

    /// The typed title, trimmed; nil when nothing is left or a list of the user's own or a planning level has it already
    /// (`levelTitles`), whatever the case of its letters.
    static func newTitle(_ typed: String, existing: [String], levelTitles: [String]) -> String? {
        let title = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let taken = (existing + levelTitles).map { $0.lowercased() }
        return taken.contains(title.lowercased()) ? nil : title
    }
}
