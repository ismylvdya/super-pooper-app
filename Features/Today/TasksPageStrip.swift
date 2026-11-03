import Foundation

/// A page of the Tasks tab: a backlog list left of the pool, a block of a paged layout, or all of Today in the other
/// layouts.
enum TasksPage: Hashable {
    case backlog(String)
    case block(TodayBlockID)
    case today

    /// The day's pages show the day's name; a backlog page shows its list's title.
    var backlogID: String? {
        if case .backlog(let id) = self { id } else { nil }
    }
}

/// The pages of the Tasks tab, left to right: the backlog pages opened so far (the farthest first), then the layout's
/// blocks when it is paged, else Today as one page. Opening a backlog page puts it at the start.
enum TasksPageStrip {
    static func pages(layout: ScreenLayout, opened: Int, backlog: [BacklogList]) -> [TasksPage] {
        let lists = backlog.prefix(max(opened, 0)).reversed().map { TasksPage.backlog($0.id) }
        return lists + (layout.isPaged ? layout.blocks.map { .block($0.block) } : [.today])
    }

    /// The pool's page.
    static func homeIndex(layout: ScreenLayout, opened: Int) -> Int {
        max(opened, 0) + (layout.isPaged ? layout.blocks.firstIndex { $0.block == .pool } ?? 0 : 0)
    }

    /// The page a drag asks for: a block of a layout that is not paged is on the Today page.
    static func index(of page: TasksPage, in pages: [TasksPage]) -> Int? {
        if let index = pages.firstIndex(of: page) { return index }
        if case .block = page { return pages.firstIndex(of: .today) }
        return nil
    }
}
