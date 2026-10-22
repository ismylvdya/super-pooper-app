import Foundation

/// URLs the app opens (`superpooper://…`), used by widgets and notifications too.
enum DeepLink {
    static let scheme = "superpooper"

    static func task(_ name: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "task"
        components.path = "/" + name
        return components.url
    }
}
