import Foundation

/// The times of a timed task or habit as today has them: the note's times, except the blocks moved today — dragged to
/// another time or to the pool, or snoozed from their notification. Only for the logical day the moves were made on; the
/// note never changes, so tomorrow it is as written (a habit's time for every day is set only in its settings, a task's
/// by dragging it, which writes its note). A move of a time the note no longer has is ignored.
struct TodayTimes: Sendable {
    let moves: [TimeMove]

    init(_ moves: [TimeMove] = []) {
        self.moves = moves
    }

    /// The blocks the task has on today's timeline, in the order of `written`, the times its note gives today (a
    /// habit's reminder times, a task's due time).
    func blocks(of task: TaskItem, written: [LocalTime]) -> [BlockTime] {
        written.compactMap { slot in
            guard let move = move(of: task, slot) else { return BlockTime(slot) }
            return move.time.map { BlockTime(written: slot, time: $0) }
        }
    }

    /// A habit's blocks today, from its reminder times.
    func blocks(of habit: TaskItem) -> [BlockTime] {
        blocks(of: habit, written: habit.habitTimes)
    }

    /// The reminder times sent to the pool today, in the note's order.
    func pooled(of habit: TaskItem) -> [LocalTime] {
        habit.habitTimes.filter { slot in move(of: habit, slot).map { $0.time == nil } ?? false }
    }

    /// The block of `slot` moved to `time` on the timeline; back at its own time it is as written again.
    func moving(_ task: TaskItem, slot: LocalTime, to time: LocalTime) -> [TimeMove] {
        replacing(task, slot, with: time == slot ? nil : TimeMove(task: task.name, slot: slot, time: time))
    }

    /// The block of `slot` dropped in the pool.
    func pooling(_ task: TaskItem, slot: LocalTime) -> [TimeMove] {
        replacing(task, slot, with: TimeMove(task: task.name, slot: slot, time: nil))
    }

    /// The habit dragged from the pool to `time`: its first reminder time sent to the pool today stands there. Nil when
    /// none was (a habit without reminder times has no block to place).
    func placing(_ habit: TaskItem, at time: LocalTime) -> [TimeMove]? {
        pooled(of: habit).first.map { moving(habit, slot: $0, to: time) }
    }

    /// The task got a new time in its note: what was moved today of its old time no longer applies.
    func clearing(_ task: TaskItem) -> [TimeMove] {
        moves.filter { !$0.task.isSameNoteName(as: task.name) }
    }

    /// The moves of a renamed task go with it.
    func renaming(from old: String, to new: String) -> [TimeMove] {
        moves.map { $0.task.isSameNoteName(as: old) ? TimeMove(task: new, slot: $0.slot, time: $0.time) : $0 }
    }

    private func move(of task: TaskItem, _ slot: LocalTime) -> TimeMove? {
        moves.last { $0.task.isSameNoteName(as: task.name) && $0.slot == slot }
    }

    private func replacing(_ task: TaskItem, _ slot: LocalTime, with move: TimeMove?) -> [TimeMove] {
        moves.filter { !($0.task.isSameNoteName(as: task.name) && $0.slot == slot) } + (move.map { [$0] } ?? [])
    }
}
