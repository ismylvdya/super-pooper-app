import Foundation

/// The Pleasant and Need energy chips of a task: at most one is on, as the one feel property says, and tapping the one
/// that is on goes back to neutral.
enum FeelChip: CaseIterable, Sendable {
    case pleasant
    case needEnergy

    var feel: TaskFeel {
        switch self {
        case .pleasant: .pleasant
        case .needEnergy: .needEnergy
        }
    }

    static func toggling(_ chip: FeelChip, current: TaskFeel) -> TaskFeel {
        current == chip.feel ? .neutral : chip.feel
    }
}
