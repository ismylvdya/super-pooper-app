import Foundation

/// Whole-number amounts offered by a habit's entry control, including zero and the maximum.
struct HabitQuantity: Hashable, Codable, Sendable {
    var maximum: Int
    var step: Int

    var isValid: Bool { step > 0 && maximum >= step }

    func accepts(_ value: Int) -> Bool {
        isValid && value >= 0 && value <= maximum && (value == maximum || value.isMultiple(of: step))
    }
}
