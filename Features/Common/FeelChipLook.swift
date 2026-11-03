import SwiftUI

/// How the Pleasant and Need energy chips show: each knows its look and its title.
extension FeelChip {
    var look: ChipLook {
        switch self {
        case .pleasant: .pleasant
        case .needEnergy: .needEnergy
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .pleasant: "taskPage.chip.pleasant"
        case .needEnergy: "taskPage.chip.needEnergy"
        }
    }

    /// The chip's identifier on the task page (UI tests find it by this).
    var chipIdentifier: String {
        switch self {
        case .pleasant: "taskPage.chip.pleasant"
        case .needEnergy: "taskPage.chip.needEnergy"
        }
    }
}
