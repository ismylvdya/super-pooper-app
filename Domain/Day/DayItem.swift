import Foundation

/// A task as it appears in today's pool or timeline.
struct DayItem: Identifiable, Hashable, Sendable {
    let task: TaskItem
    let state: DayItemState
    let problems: [TaskProblem]
    /// How many parents above it in the pool (a subtask sits under its parent, indented).
    var depth = 0
    /// Its subtasks sit under it in the pool.
    var hasSubtasks = false
    /// The next action of a task shown one at a time: that task's name, over its own (`TaskSteps`).
    var project: String?

    var id: String { task.name }
    var isHabit: Bool { task.isHabit }
    var isDone: Bool { state.isDone }
    /// Nothing is left to do today (see `HabitMarking.isDayClosed`): it leaves the pool and the timeline.
    var isFinished: Bool {
        guard isHabit else { return isDone }
        return HabitMarking.isDayClosed(state.mark, twiceADay: task.isTwiceADay)
    }
}

extension DayItem {
    /// A note as an item outside a day plan (a list of the Lists tab, a task waiting under Not today): done by its
    /// status.
    init(listed task: TaskItem) {
        self.init(task: task, state: task.status == .done ? .marked(.done) : .open, problems: task.problems)
    }

    /// A habit on one of its days outside a day plan (a day of its history): the day's mark.
    init(habit: TaskItem, on day: LocalDate) {
        self.init(task: habit, state: habit.mark(on: day).map(DayItemState.marked) ?? .open, problems: habit.problems)
    }
}
