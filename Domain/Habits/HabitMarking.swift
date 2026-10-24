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

    /// Nothing is left to do on a day with this mark. A twice-a-day habit, or one with two or more reminders
    /// a day, waits for Twice (its next reminder still comes after the first Done); any other habit for any mark.
    static func isDayClosed(_ mark: HabitMark?, twiceADay: Bool, remindersPerDay: Int) -> Bool {
        guard let mark else { return false }
        return mark == .twice || !(twiceADay || remindersPerDay >= 2)
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
