import Foundation

/// What a search of notes finds, in titled groups: one way for every page that searches notes (`SearchPage`) — all
/// tasks, the habits, the archive, a list. Nothing until something is typed.
struct SearchSection: Equatable, Sendable {
    enum Title: Equatable, Sendable {
        /// A text key of the app.
        case key(String)
        /// A title as it is (a planning level's, already in words).
        case text(String)
    }

    let title: Title
    let notes: [TaskItem]
}

enum SearchSections {
    /// Every note, in one group.
    static func notes(_ notes: [TaskItem], matching query: String) -> [SearchSection] {
        sections([(.key("search.tasks"), SearchMatcher.tasks(notes, matching: query))])
    }

    /// Habits, then repeatable tasks.
    static func habits(_ habits: [TaskItem], matching query: String) -> [SearchSection] {
        let found = SearchMatcher.tasks(habits, matching: query)
        return sections([(.key("search.habits"), found.filter { $0.kind == .habit }),
                         (.key("search.repeatable"), found.filter { $0.kind == .repeatable })])
    }

    /// Archived tasks, then archived habits and repeatable tasks.
    static func archive(_ archived: [TaskItem], matching query: String) -> [SearchSection] {
        let found = SearchMatcher.tasks(archived, matching: query)
        return sections([(.key("archive.tasks"), found.filter { $0.kind == .task }),
                         (.key("archive.habits"), found.filter { $0.kind != .task })])
    }

    /// A list's own groups (its planning levels, already matched by the list), then its filed tasks.
    static func list(_ contents: TaskListContents, levelTitle: (TaskStatus) -> String) -> [SearchSection] {
        sections(contents.groups.map { (.text(levelTitle($0.status)), $0.tasks) } + [(.key("lists.filed"), contents.filed)])
    }

    private static func sections(_ groups: [(SearchSection.Title, [TaskItem])]) -> [SearchSection] {
        groups.filter { !$0.1.isEmpty }.map { SearchSection(title: $0.0, notes: $0.1) }
    }
}
