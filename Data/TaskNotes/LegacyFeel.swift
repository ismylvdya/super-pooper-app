import Foundation

/// Older notes kept the feel as two booleans, `need_energy` and `pleasant`.
enum LegacyFeel {
    /// `need_energy: true` = needs energy, else `pleasant: true` = pleasant; neither set (or both false) = neutral.
    static func feel(needEnergy: Bool?, pleasant: Bool?) -> TaskFeel {
        if needEnergy == true { return .needEnergy }
        return pleasant == true ? .pleasant : .neutral
    }
}
