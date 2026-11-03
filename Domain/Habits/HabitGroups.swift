import Foundation

/// The two groups of the Habits tab: habits to keep track of, and tasks that simply repeat. A repeatable subtask of an
/// active habit is no row of its own: it shows on its parent's page.
struct HabitGroups: Equatable, Sendable {
    let tracked: [TaskItem]
    let repeatable: [TaskItem]

    /// `habits`: the rows to group (a search may have narrowed them); `active`: all active habits, the parents among them.
    init(_ habits: [TaskItem], active: [TaskItem]? = nil) {
        let parents = active ?? habits
        let rows = habits.filter { !RepeatableSubtasks.isRepeatableSubtask($0, in: parents) }
        tracked = rows.filter { !$0.habit.repeatable }
        repeatable = rows.filter(\.habit.repeatable)
    }

    /// The whole order after a row moved inside one group: that group first, then the other, each in its order.
    func order(moving source: IndexSet, to destination: Int, inRepeatable: Bool) -> [String] {
        var moved = (inRepeatable ? repeatable : tracked).map(\.name)
        moved.move(fromOffsets: source, toOffset: destination)
        let other = (inRepeatable ? tracked : repeatable).map(\.name)
        return inRepeatable ? other + moved : moved + other
    }
}
