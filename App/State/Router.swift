import Foundation
import Observation

/// Pushed pages of the main navigation stack.
enum Route: Hashable {
    case task(String)
    case settings
    case archive
    #if DEBUG
    case debugNotifications
    case debugWidgets
    #endif
}

/// Navigation state; deep links (`superpooper://…`) and notifications go through it too.
@MainActor
@Observable
final class Router {
    var path: [Route] = []
    var isReviewPresented = false
    var isProblemsPresented = false

    func open(_ route: Route) { path.append(route) }
    func popToRoot() { path.removeAll() }

    /// `superpooper://task/<name>`, `superpooper://settings`, `superpooper://review`, `superpooper://archive`.
    func handle(_ url: URL) {
        guard url.scheme == DeepLink.scheme else { return }
        switch url.host() {
        case "task":
            let name = url.path().removingPercentEncoding.map { String($0.dropFirst()) } ?? ""
            if !name.isEmpty { path = [.task(name)] }
        case "settings": path = [.settings]
        case "archive": path = [.settings, .archive]
        case "review": popToRoot(); isReviewPresented = true
        #if DEBUG
        case "debug-notifications": path = [.settings, .debugNotifications]
        case "debug-widgets": path = [.settings, .debugWidgets]
        #endif
        default: popToRoot()
        }
    }
}
