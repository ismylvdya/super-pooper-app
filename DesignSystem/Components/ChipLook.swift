import SwiftUI

/// What a task's property looks like wherever it is drawn as a chip or an icon: its symbol and its color. One table
/// for the chips of the rows, their order in the settings and the morning review.
enum ChipLook: CaseIterable {
    case problem, high, needEnergy, pleasant, habit

    var icon: Icon {
        switch self {
        case .problem: .problem
        case .high: .high
        case .needEnergy: .energy
        case .pleasant: .pleasant
        case .habit: .habit
        }
    }

    /// Its color on a plate filled for high priority, where its own may not read; nil = its own.
    var tintOnFill: ColorToken? {
        switch self {
        case .needEnergy: .energyOnFill
        case .pleasant: .heartOnFill
        case .problem, .high, .habit: nil
        }
    }

    /// Its own color; nil = the grey of a plain chip.
    var tint: ColorToken? {
        switch self {
        case .problem: .problem
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

    /// The same on a row, whose plate may be filled for high priority.
    func color(of look: ChipLook, onFill: Bool) -> Color {
        if onFill, let tint = look.tintOnFill { return color(tint) }
        return color(of: look)
    }
}
