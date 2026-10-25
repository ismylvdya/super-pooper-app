import Foundation

/// URLs the app opens (`superpooper://…`), used by widgets and notifications too.
enum DeepLink {
    static let scheme = "superpooper"
    /// Any tap on a widget opens Today.
    static let today = URL(string: "\(scheme)://today")

    /// The habit's page in the Habits tab (habit widgets open it).
    static func habit(_ name: String) -> URL? { url(host: "habit", name: name) }

    static let habits = URL(string: "\(scheme)://habits")
    static let clock = URL(string: "\(scheme)://clock")

    private static func url(host: String, name: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/" + name
        return components.url
    }
}
