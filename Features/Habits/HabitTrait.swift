import Foundation

/// A trait that sets a habit apart in the Habits list, shown by its name under the habit's name.
enum HabitTrait: Hashable, Sendable {
    case routine(HabitTimeOfDay)
    case twiceADay

    var titleKey: String {
        switch self {
        case .routine(let part): "habits.trait." + part.rawValue
        case .twiceADay: "habits.trait.twice"
        }
    }
}
