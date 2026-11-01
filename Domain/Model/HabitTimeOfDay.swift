import Foundation

/// The part of the day a habit belongs to; the pool lifts habits of the current part.
enum HabitTimeOfDay: String, Codable, CaseIterable, Sendable {
    case morning
    case day
    case evening
}
