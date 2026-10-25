import Foundation
import Observation

/// The tabs of the app, in tab bar order.
enum AppTab: String, CaseIterable, Hashable {
    case today
    case habits
    case settings
}

/// Pushed pages of the tabs' navigation stacks.
enum Route: Hashable {
    case task(String)
    case newTask
    case newHabit
    case search
    case taskSettings
    case habitSettings
    case archive
    case trash
    case routines
    case poolOrder
    case conflicts
    case conflict(String)
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
    var isInboxEntryPresented = false
    /// Grows on every tap on the Today tab: Today goes back to today's date.
    private(set) var todayTaps = 0

    /// The tab bar's selection: a tap on Today (also when it is already selected) brings back today.
    func select(_ tab: AppTab) {
        if tab == .today { todayTaps += 1 }
        self.tab = tab
    }

    /// The stack of the selected tab.
    var path: [Route] {
        get { paths[tab] ?? [] }
        set { paths[tab] = newValue }
    }

    func open(_ route: Route) { path.append(route) }
    func popToRoot() { path.removeAll() }

    func show(_ tab: AppTab, _ routes: [Route] = []) {
        self.tab = tab
        paths[tab] = routes
    }

    /// `superpooper://task/<name>`, `superpooper://habit/<name>`, `superpooper://habits`, `superpooper://settings`,
    /// `superpooper://review`, `superpooper://archive`, `superpooper://trash`, `superpooper://clock`,
    /// `superpooper://new-task` and `superpooper://new-inbox` (also the Home Screen quick actions).
    func handle(_ url: URL) {
        guard url.scheme == DeepLink.scheme else { return }
        let name = url.path().removingPercentEncoding.map { String($0.dropFirst()) } ?? ""
        switch url.host() {
        case "task": if !name.isEmpty { show(.today, [.task(name)]) }
        case "habit": show(.habits, name.isEmpty ? [] : [.task(name)])
        case "habits": show(.habits)
        case "settings", "clock": show(.settings)
        case "archive": show(.settings, [.archive])
        case "trash": show(.settings, [.trash])
        case "review": show(.today); isReviewPresented = true
        case "new-task": isReviewPresented = false; show(.today, [.newTask])
        case "new-inbox": isReviewPresented = false; show(.today); isInboxEntryPresented = true
        #if DEBUG
        case "debug-notifications": show(.settings, [.debugNotifications])
        case "debug-widgets": show(.settings, [.debugWidgets])
        #endif
        default: show(.today)
        }
    }
}
