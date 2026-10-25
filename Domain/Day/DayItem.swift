import Foundation

/// The state of a task for today.
enum DayItemState: Hashable, Sendable {
    case open
    /// Regular tasks are always `.done`; recurring ones carry their mark.
    case marked(HabitMark)

    var isDone: Bool { self != .open }
    var mark: HabitMark? {
        if case .marked(let mark) = self { return mark }
        return nil
    }
}

/// What keeps a task from being checked off.
enum Blocker: Hashable, Sendable {
    case task(String)
    case event(title: String, end: Date)
}

/// A task as it appears in today's pool or timeline.
struct DayItem: Identifiable, Hashable, Sendable {
    let task: TaskNote
    let state: DayItemState
    let blockers: [Blocker]
    let problems: [TaskProblem]
    /// How many parents above it in the pool (a subtask sits under its parent, indented).
    var depth = 0

    var id: String { task.name }
    var isHabit: Bool { task.isHabit }
    var isDone: Bool { state.isDone }
    var isBlocked: Bool { !isDone && !blockers.isEmpty }
    /// Nothing is left to do today (see `HabitMarking.isDayClosed`): it leaves the pool and the timeline.
    var isFinished: Bool {
        guard isHabit else { return isDone }
        return HabitMarking.isDayClosed(state.mark, twiceADay: task.habit.twiceADay, remindersPerDay: task.habitTimes.count)
    }
}
