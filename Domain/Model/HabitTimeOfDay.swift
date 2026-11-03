import Foundation

/// The routine a habit belongs to: its section of the pool by default and its shared plate there.
enum HabitTimeOfDay: String, Codable, CaseIterable, Sendable {
    case morning
    case evening
}
