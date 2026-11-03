import Foundation

/// The pool cut into runs: the members of a worm (with their subtasks), and habits of one routine (morning or evening)
/// that stand next to each other, share one plate; everything else is a run of one.
enum PoolSegments {
    struct Segment: Identifiable, Hashable, Sendable {
        let items: [DayItem]
        /// The worm the run is (`DayWorm`), nil for a routine's run or a task on its own.
        var wormID: String?
        var id: String { items.first?.id ?? "" }
        var isShared: Bool { items.count > 1 }
    }

    static func make(_ pool: [DayItem], worms: [DayWorm] = []) -> [Segment] {
        var result: [Segment] = []
        for item in pool {
            let last = result.last
            if let worm = worm(of: item, in: worms) {
                if last?.wormID == worm { append(item, to: &result) } else { result.append(Segment(items: [item], wormID: worm)) }
            } else if item.depth > 0, last?.wormID != nil {
                // A member's subtask stands on the worm's plate under it.
                append(item, to: &result)
            } else if let part = routine(of: item), let previous = last?.items.last, last?.wormID == nil, routine(of: previous) == part {
                append(item, to: &result)
            } else {
                result.append(Segment(items: [item]))
            }
        }
        return result
    }

    private static func append(_ item: DayItem, to segments: inout [Segment]) {
        let last = segments[segments.count - 1]
        segments[segments.count - 1] = Segment(items: last.items + [item], wormID: last.wormID)
    }

    private static func worm(of item: DayItem, in worms: [DayWorm]) -> String? {
        guard item.depth == 0 else { return nil }
        return worms.first { $0.members.containsNoteName(item.id) }?.id
    }

    /// Open habits of the morning or evening routine; done ones stand alone at the end of the pool. Tasks with a part of
    /// the day only sort with it, each on its own plate.
    private static func routine(of item: DayItem) -> HabitTimeOfDay? {
        guard item.isHabit, !item.isDone, let part = item.task.habit.timeOfDay else { return nil }
        return part
    }
}
