import Foundation

/// The two groups of the Habits tab: habits to keep track of, and tasks that simply repeat.
struct HabitGroups: Equatable, Sendable {
    let tracked: [TaskNote]
    let repeatable: [TaskNote]

    init(_ habits: [TaskNote]) {
        tracked = habits.filter { !$0.habit.repeatable }
        repeatable = habits.filter(\.habit.repeatable)
    }

    /// The whole order after a row moved inside one group: that group first, then the other, each in its order.
    func order(moving source: IndexSet, to destination: Int, inRepeatable: Bool) -> [String] {
        var moved = (inRepeatable ? repeatable : tracked).map(\.name)
        moved.move(fromOffsets: source, toOffset: destination)
        let other = (inRepeatable ? tracked : repeatable).map(\.name)
        return inRepeatable ? other + moved : moved + other
    }
}
