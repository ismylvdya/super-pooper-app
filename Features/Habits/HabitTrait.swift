import Foundation

/// A trait that sets a habit apart in the Habits list, shown as its icon (its name is for VoiceOver).
enum HabitTrait: Hashable, Sendable {
    case routine(HabitTimeOfDay)
    case twiceADay

    var icon: Icon {
        switch self {
        case .routine(.morning): .routineMorning
        case .routine(.day): .routineDay
        case .routine(.evening): .routineEvening
        case .twiceADay: .twiceADay
        }
    }

    var titleKey: String {
        switch self {
        case .routine(let part): "habitPage.timeOfDay." + part.rawValue
        case .twiceADay: "action.twice"
        }
    }
}
