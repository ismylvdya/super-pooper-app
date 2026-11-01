import SwiftUI

/// How the Today / Tomorrow chips show: each knows its icon and its day's name.
extension QuickDue {
    var icon: Icon {
        switch self {
        case .today: .today
        case .tomorrow: .tomorrow
        }
    }

    /// The day's name, as a due date says it.
    var title: LocalizedStringKey {
        switch self {
        case .today: "due.today"
        case .tomorrow: "due.tomorrow"
        }
    }

    /// The chip's identifier on the task page (UI tests find it by this).
    var chipIdentifier: String {
        switch self {
        case .today: "taskPage.chip.today"
        case .tomorrow: "taskPage.chip.tomorrow"
        }
    }
}
