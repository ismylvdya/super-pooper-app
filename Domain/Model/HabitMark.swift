import Foundation

/// The single mark a recurring task can have for a day.
enum HabitMark: String, Codable, CaseIterable, Sendable {
    case done
    case partial
    case twice
}
