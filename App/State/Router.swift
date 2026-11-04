import Foundation
import Observation

/// The tabs of the app, in tab bar order. The first one is labelled Tasks; its raw value stays `today` for links and
/// identifiers.
enum AppTab: String, CaseIterable, Hashable {
    case today
    case habits
    case settings
}

extension NewItemSeed {
    /// "+" on a tab: a habit in Habits, a task elsewhere.
    static func opening(on tab: AppTab) -> NewItemSeed {
        NewItemSeed(kind: tab == .habits ? .habit : .task)
    }
}

/// What a search looks through: Today's finds events too, the Lists page's only task notes.
enum SearchScope: Hashable {
    case tasksAndEvents, tasks
}

/// Pushed pages of the tabs' navigation stacks.
enum Route: Hashable {
    case task(String)
    /// The new-item page a "+" opens.
    case newItem(NewItemSeed)
    case search(SearchScope)
    case taskSettings
    case habitSettings
    case clockSettings
    case tabBarSettings
    case plainTaskSettings
    case archive
    case trash
    case routines
    case poolOrder
    case chipOrder
    case conflicts
    case conflict(String)
    /// The Lists page, opened from Today's top left button.
    case lists
    /// A list of the Lists page, by its id in `lists.json`.
    case list(String)
    #if DEBUG
    case debugNotifications
    case debugWidgets
    #endif
}

/// Navigation state: the selected tab and one stack per tab. Deep links (`superpooper://…`) and
/// notifications go through it too.
@MainActor
@Observable
final class Router {
    var tab: AppTab = .today
    var paths: [AppTab: [Route]] = [:]
    var isReviewPresented = false
    var isProblemsPresented = false
    /// A sheet that shows the banner on its own bar is up: the tabs' banner, under the sheet, steps aside.
    var presentsBannerSheet: Bool { isReviewPresented || isProblemsPresented }
    /// Grows on every tap on the Tasks tab: Today goes back to today's pool.
    private(set) var tasksTaps = 0

    /// The tab bar's selection: a tap on Tasks (also when it is already selected) brings back today's pool. Tapping the
    /// tab that is already open goes back to its first page, as the system tab bar does; coming from another tab finds
    /// the pages as they were left (a new task's page among them).
    func select(_ tab: AppTab) {
        if tab == .today { tasksTaps += 1 }
        if tab == self.tab { paths[tab] = [] }
        self.tab = tab
    }

    /// The stack of the selected tab.
    var path: [Route] {
        get { paths[tab] ?? [] }
        set { paths[tab] = newValue }
    }

    func open(_ route: Route) { path.append(route) }

    /// "+": the new-item page on the selected tab, a habit in Habits unless `seed` says otherwise.
    func openNewItem(_ seed: NewItemSeed? = nil) {
        let route = Route.newItem(seed ?? .opening(on: tab))
        // The page is open already: the "+" and the tab under it may both answer one tap.
        if path.last == route { return }
        open(route)
    }
    func popToRoot() { path.removeAll() }

    func show(_ tab: AppTab, _ routes: [Route] = []) {
        self.tab = tab
        paths[tab] = routes
    }

    /// `superpooper://task/<name>`, `superpooper://habit/<name>`, `superpooper://habits`, `superpooper://lists[/<id>]`
    /// (the Lists page on Tasks), `superpooper://settings`,
    /// `superpooper://review`, `superpooper://archive`, `superpooper://trash`, `superpooper://clock`,
    /// `superpooper://new-task` (also the Home Screen quick action).
    func handle(_ url: URL) {
        guard url.scheme == DeepLink.scheme else { return }
        let name = url.path().removingPercentEncoding.map { String($0.dropFirst()) } ?? ""
        switch url.host() {
        case "task": if !name.isEmpty { show(.today, [.task(name)]) }
        case "habit": show(.habits, name.isEmpty ? [] : [.task(name)])
        case "habits": show(.habits)
        case "lists": show(.today, [.lists] + (name.isEmpty ? [] : [.list(name)]))
        case "settings", "clock": show(.settings)
        case "archive": show(.settings, [.archive])
        case "trash": show(.settings, [.trash])
        case "review": show(.today); isReviewPresented = true
        case "new-task": isReviewPresented = false; show(.today, [.newItem(.opening(on: .today))])
        #if DEBUG
        case "debug-notifications": show(.settings, [.debugNotifications])
        case "debug-widgets": show(.settings, [.debugWidgets])
        #endif
        default: show(.today)
        }
    }
}
