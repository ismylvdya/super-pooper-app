import Foundation

/// A habit's reminder times as today has them: the note's times, except the blocks dragged today — to another time on
/// the timeline, or to the pool (no time and no notification today). Only for the logical day the moves were made on;
/// the note never changes, so tomorrow the habit is as written, and a time for every day is set only in its settings.
/// A move of a time the note no longer has is ignored.
struct HabitDayTimes: Sendable {
    let moves: [HabitTimeMove]

    init(_ moves: [HabitTimeMove] = []) {
        self.moves = moves
    }

    /// The blocks the habit has on today's timeline, in the note's order.
    func blocks(of habit: TaskItem) -> [BlockTime] {
        habit.habitTimes.compactMap { slot in
            guard let move = move(of: habit, slot) else { return BlockTime(slot) }
            return move.time.map { BlockTime(written: slot, time: $0) }
        }
    }

    /// The reminder times sent to the pool today, in the note's order.
    func pooled(of habit: TaskItem) -> [LocalTime] {
        habit.habitTimes.filter { slot in move(of: habit, slot).map { $0.time == nil } ?? false }
    }

    /// The block of `slot` dragged to `time` on the timeline; back at its own time it is as written again.
    func moving(_ habit: TaskItem, slot: LocalTime, to time: LocalTime) -> [HabitTimeMove] {
        replacing(habit, slot, with: time == slot ? nil : HabitTimeMove(habit: habit.name, slot: slot, time: time))
    }

    /// The block of `slot` dropped in the pool.
    func pooling(_ habit: TaskItem, slot: LocalTime) -> [HabitTimeMove] {
        replacing(habit, slot, with: HabitTimeMove(habit: habit.name, slot: slot, time: nil))
    }

    /// The habit dragged from the pool to `time`: its first reminder time sent to the pool today stands there. Nil when
    /// none was (a habit without reminder times has no block to place).
    func placing(_ habit: TaskItem, at time: LocalTime) -> [HabitTimeMove]? {
        pooled(of: habit).first.map { moving(habit, slot: $0, to: time) }
    }

    /// The moves of a renamed habit go with it.
    func renaming(from old: String, to new: String) -> [HabitTimeMove] {
        moves.map { $0.habit.isSameNoteName(as: old) ? HabitTimeMove(habit: new, slot: $0.slot, time: $0.time) : $0 }
    }

    private func move(of habit: TaskItem, _ slot: LocalTime) -> HabitTimeMove? {
        moves.last { $0.habit.isSameNoteName(as: habit.name) && $0.slot == slot }
    }

    private func replacing(_ habit: TaskItem, _ slot: LocalTime, with move: HabitTimeMove?) -> [HabitTimeMove] {
        moves.filter { !($0.habit.isSameNoteName(as: habit.name) && $0.slot == slot) } + (move.map { [$0] } ?? [])
    }
}
