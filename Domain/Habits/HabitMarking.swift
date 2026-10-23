import Foundation

/// How taps and notification buttons change a habit's mark for one day.
enum HabitMarking {
    /// Tap: none → Done (→ Twice for twice-a-day habits) → none. Partially goes to Twice when the
    /// habit allows it, otherwise back to none.
    static func next(after mark: HabitMark?, twiceADay: Bool) -> HabitMark? {
        switch mark {
        case nil: .done
        case .done, .partial: twiceADay ? .twice : nil
        case .twice: nil
        }
    }

    /// A button pressed on a reminder notification. With two or more reminders a day, the second
    /// Done of the day is Twice; Partially only marks an unmarked day and never downgrades.
    static func notificationMark(_ action: HabitMark, current: HabitMark?, remindersPerDay: Int) -> HabitMark {
        switch action {
        case .done:
            guard let current else { return .done }
            return remindersPerDay >= 2 ? .twice : current
        case .partial:
            return current ?? .partial
        case .twice:
            return .twice
        }
    }
}
