import Foundation

/// The pool cut into runs: habits of one routine (morning or evening) that stand next to each other
/// share one plate; everything else is a run of one.
enum PoolSegments {
    struct Segment: Identifiable, Hashable, Sendable {
        let items: [DayItem]
        var id: String { items.first?.id ?? "" }
        var isRoutine: Bool { items.count > 1 }
    }

    static func make(_ pool: [DayItem]) -> [Segment] {
        var result: [[DayItem]] = []
        for item in pool {
            if let part = routine(of: item), let last = result.last?.last, routine(of: last) == part {
                result[result.count - 1].append(item)
            } else {
                result.append([item])
            }
        }
        return result.map(Segment.init)
    }

    /// Open habits of the morning or evening routine; done ones stand alone at the end of the pool.
    private static func routine(of item: DayItem) -> HabitTimeOfDay? {
        guard item.isHabit, !item.isDone, let part = item.task.habit.timeOfDay, part != .day else { return nil }
        return part
    }
}
