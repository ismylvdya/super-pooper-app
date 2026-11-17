import Foundation

/// Today's pool is what carries `🏊 in_today_pool` (`TaskItem.isInTodayPool`), all of it in Next actions: what comes into
/// the pool from Soon or Someday moves to Next actions with it. The day's turn puts it on what is due to
/// come up (`isDue`), Not today takes it off, and a date set to today or earlier puts it on (`settled`). A task with a
/// time today stands on the timeline by that time, with or without it; a habit comes up by its rule and never has it.
enum TodayPool {
    /// What the day's turn brings into the pool: an undated task of Next actions, and a task of Next actions, Soon or
    /// Someday dated today or earlier. A task with a time today stands on the timeline instead, a project holds tasks
    /// rather than being one, and a step waiting for an earlier one (`waiting`) is not up yet.
    static func isDue(_ task: TaskItem, today: LocalDate, boundary: LocalTime, waiting: Set<String> = []) -> Bool {
        guard !task.isHabit, !task.showsAsProject, TaskStatus.open.contains(task.status), !waiting.contains(task.name) else { return false }
        guard let due = task.due else { return task.status.isThisWeek }
        let day = due.logicalDay(boundary: boundary)
        return day < today || (day == today && due.time == nil)
    }

    /// What the day's turn of `today` puts the mark on, by name: `isDue` for each task, the waiting steps and what the
    /// review planned the day before kept out (`isNotTomorrow`) left out.
    static func dayTurn(_ tasks: [TaskItem], today: LocalDate, boundary: LocalTime) -> Set<String> {
        let waiting = TaskSteps.waiting(in: tasks)
        return Set(tasks.filter { !$0.isNotTomorrow && isDue($0, today: today, boundary: boundary, waiting: waiting) }.map(\.name))
    }

    /// Kept out of tomorrow's pool in the review planned today: what tomorrow's turn would bring that is marked so.
    static func keptOutTomorrow(_ tasks: [TaskItem], tomorrow: LocalDate, boundary: LocalTime) -> [TaskItem] {
        let waiting = TaskSteps.waiting(in: tasks)
        return NameOrder.sorted(tasks.filter { $0.isNotTomorrow && isDue($0, today: tomorrow, boundary: boundary, waiting: waiting) })
    }

    /// The tasks as the day's turn of `today` leaves them: in the pool exactly what `dayTurn` brings in.
    static func turning(_ tasks: [TaskItem], today: LocalDate, boundary: LocalTime) -> [TaskItem] {
        let due = dayTurn(tasks, today: today, boundary: boundary)
        return tasks.map { task in
            var task = task
            task.isInTodayPool = due.contains(task.name)
            if task.isInTodayPool { task.status = .thisWeek }
            return task
        }
    }

    /// A task taken out of today's pool or brought into it takes its open subtasks along, all the way down: they stand
    /// under it there. The ones that already are where it goes need nothing.
    static func following(_ parent: TaskItem, into inPool: Bool, in tasks: [TaskItem]) -> [String] {
        SubtaskCascade.subtasks(of: parent, in: tasks, change: .completion).filter { $0.isInTodayPool != inPool }.map(\.name)
    }

    /// The task as an edit leaves it: a date set to today or earlier brings it into the pool (a time today puts it on the
    /// timeline instead), a later one takes it out, and a later level without such a date takes it out too. An edit that says so itself (`.inTodayPool`) decides.
    static func settled(_ task: TaskItem, was: TaskItem?, changes: [TaskEdit], today: LocalDate, boundary: LocalTime) -> TaskItem {
        var task = task
        if task.isHabit { task.isInTodayPool = false }
        guard !task.isHabit, !changes.contains(where: \.isTodayPool) else { return task }
        if task.due != was?.due, let due = task.due {
            let day = due.logicalDay(boundary: boundary)
            task.isInTodayPool = day < today || (day == today && due.time == nil)
            // The pool is Next actions': a task of Soon or Someday that comes into it moves there.
            if task.isInTodayPool, TaskStatus.open.contains(task.status) { task.status = .thisWeek }
        } else if task.status != was?.status, !task.status.isThisWeek, !task.status.isCompleted,
                  !isDue(task, today: today, boundary: boundary) {
            task.isInTodayPool = false
        }
        return task
    }
}

extension TaskEdit {
    var isTodayPool: Bool {
        if case .inTodayPool = self { return true }
        return false
    }
}
