import SwiftUI

/// What a task's property looks like wherever it is drawn as a chip or an icon: its symbol and its color. One table
/// for the chips of the rows, their order in the settings and the morning review.
enum ChipLook: CaseIterable {
    case problem, blocked, high, needEnergy, pleasant, habit

    var icon: Icon {
        switch self {
        case .problem: .problem
        case .blocked: .links
        case .high: .high
        case .needEnergy: .energy
        case .pleasant: .pleasant
        case .habit: .habit
        }
    }

    /// Its own color; nil = the grey of a plain chip.
    var tint: ColorToken? {
        switch self {
        case .problem: .problem
        case .blocked: nil
        case .high: .high
        case .needEnergy: .energy
        case .pleasant: .heart
        case .habit: .habit
        }
    }
}

extension DesignTokens {
    /// The color a property's chip or icon is drawn in.
    func color(of look: ChipLook) -> Color {
        color(look.tint ?? .secondaryText)
    }
}
