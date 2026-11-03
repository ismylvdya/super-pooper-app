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
        } + placedBlocks(of: task)
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
        if isPlaced(task, slot) {
            return replacing(task, slot, with: TimeMove(task: task.name, slot: slot, time: time, placed: true))
        }
        return replacing(task, slot, with: time == slot ? nil : TimeMove(task: task.name, slot: slot, time: time))
    }

    /// The block of `slot` dropped in the pool.
    func pooling(_ task: TaskItem, slot: LocalTime) -> [TimeMove] {
        if isPlaced(task, slot) { return replacing(task, slot, with: nil) }
        return replacing(task, slot, with: TimeMove(task: task.name, slot: slot, time: nil))
    }

    /// The habit dragged from the pool to `time`: its first reminder time sent to the pool today stands there; a habit
    /// with none gets a block of today's own.
    func placing(_ habit: TaskItem, at time: LocalTime) -> [TimeMove] {
        if let slot = pooled(of: habit).first { return moving(habit, slot: slot, to: time) }
        return replacing(habit, time, with: TimeMove(task: habit.name, slot: time, time: time, placed: true))
    }

    /// The task got a new time in its note: what was moved today of its old time no longer applies.
    func clearing(_ task: TaskItem) -> [TimeMove] {
        moves.filter { !$0.task.isSameNoteName(as: task.name) }
    }

    /// The moves of a renamed task go with it.
    func renaming(from old: String, to new: String) -> [TimeMove] {
        moves.map { $0.task.isSameNoteName(as: old) ? TimeMove(task: new, slot: $0.slot, time: $0.time, placed: $0.placed) : $0 }
    }

    private func move(of task: TaskItem, _ slot: LocalTime) -> TimeMove? {
        moves.last { !$0.isPlaced && $0.task.isSameNoteName(as: task.name) && $0.slot == slot }
    }

    private func isPlaced(_ task: TaskItem, _ slot: LocalTime) -> Bool {
        moves.contains { $0.isPlaced && $0.task.isSameNoteName(as: task.name) && $0.slot == slot }
    }

    /// The blocks a habit has only today (`TimeMove.placed`).
    private func placedBlocks(of task: TaskItem) -> [BlockTime] {
        guard task.isHabit else { return [] }
        return moves.compactMap { move in
            guard move.isPlaced, move.task.isSameNoteName(as: task.name), let time = move.time else { return nil }
            return BlockTime(written: move.slot, time: time)
        }
    }

    private func replacing(_ task: TaskItem, _ slot: LocalTime, with move: TimeMove?) -> [TimeMove] {
        moves.filter { !($0.task.isSameNoteName(as: task.name) && $0.slot == slot) } + (move.map { [$0] } ?? [])
    }
}
