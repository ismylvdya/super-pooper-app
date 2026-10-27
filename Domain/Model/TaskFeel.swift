import Foundation

/// How doing a task feels, one property: it takes energy (or is unpleasant), it is pleasant, or neither.
enum TaskFeel: String, CaseIterable, Hashable, Codable, Sendable {
    case needEnergy, neutral, pleasant

    /// Older notes had two booleans; neither set (or both false) = neutral.
    static func legacy(needEnergy: Bool?, pleasant: Bool?) -> TaskFeel {
        if needEnergy == true { return .needEnergy }
        return pleasant == true ? .pleasant : .neutral
    }
}
