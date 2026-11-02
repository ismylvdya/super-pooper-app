import Foundation

/// Short texts about a habit for lists.
@MainActor
enum HabitSummary {
    /// The traits as one line under the name, the way the owner chose for this place (D-058): "Morning · Twice".
    /// VoiceOver hears them as a list ("Morning, Twice"), not the separator.
    struct TraitsLine: Equatable {
        let text: String
        let spoken: String
    }

    /// What sets the habit apart in the Habits list: its routine, then Twice.
    static func traits(_ habit: TaskItem) -> [HabitTrait] {
        var traits: [HabitTrait] = []
        if let part = habit.habit.timeOfDay { traits.append(.routine(part)) }
        if habit.isTwiceADay { traits.append(.twiceADay) }
        return traits
    }

    /// The traits' line; nil when the habit has none. With its bells after it (`bellsFollow`) the line ends in the same
    /// separator as between the traits, so the bells stand as one more trait ("Morning · Twice · 🔔🔔").
    static func traitsLine(_ habit: TaskItem, bellsFollow: Bool = false) -> TraitsLine? {
        let titles = traits(habit).map { L10n.string($0.titleKey) }
        guard !titles.isEmpty else { return nil }
        let separator = L10n.string("habits.traits.separator")
        return TraitsLine(text: titles.joined(separator: separator) + (bellsFollow ? separator : ""),
                          spoken: titles.formatted(.list(type: .and, width: .narrow)))
    }

    /// A bell per reminder of the day, two at most.
    static func bellCount(_ habit: TaskItem, limit: Int) -> Int { min(habit.reminderTimes.count, limit) }
}
