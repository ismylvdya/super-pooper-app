import Foundation

/// What keeps a task from being checked off.
enum Blocker: Hashable, Sendable {
    case task(String)
    case event(title: String, end: Date)
}
