import Foundation

/// How doing a task feels, one property: it takes energy (or is unpleasant), it is pleasant, or neither.
enum TaskFeel: String, CaseIterable, Hashable, Codable, Sendable {
    case needEnergy, neutral, pleasant
}
