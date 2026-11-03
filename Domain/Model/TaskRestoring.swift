import Foundation

/// The edits that take a task or habit back to how it was (Undo, .27143): every field the user's actions change, from
/// the note as it is now. Lists go back by deltas (one mark), as every edit does. A note is never taken out of
/// a parent (no edit removes a project), so the projects are left as they are.
enum TaskRestoring {
    static func edits(restoring before: TaskItem, from now: TaskItem) -> [TaskEdit] {
        var edits = statusEdits(restoring: before, from: now)
        edits += markEdits(restoring: before.marks, from: now.marks)
        let fields: [(Bool, TaskEdit)] = [
            (before.isHighPriority != now.isHighPriority, .highPriority(before.isHighPriority)),
            (before.due != now.due, .due(before.due)),
            (before.timeEstimate != now.timeEstimate, .timeEstimate(before.timeEstimate)),
            (before.subtaskOrder != now.subtaskOrder, .subtaskOrder(before.subtaskOrder)),
            (before.feel != now.feel, .feel(before.feel)),
            (before.recurrence != now.recurrence, .recurrence(before.recurrence)),
            (before.reminderTimes != now.reminderTimes, .reminderTimes(before.reminderTimes)),
            (before.timeZone != now.timeZone, .timeZone(before.timeZone)),
        ]
        return edits + fields.filter(\.0).map(\.1) + habitEdits(restoring: before.habit, from: now.habit)
    }

    /// Done goes back with its day of completion; any other status leaves done (`TaskEdit.status`).
    private static func statusEdits(restoring before: TaskItem, from now: TaskItem) -> [TaskEdit] {
        guard before.status != now.status || before.completedDate != now.completedDate else { return [] }
        if before.status == .done, let day = before.completedDate { return [.complete(on: day)] }
        return [.status(before.status)]
    }

    private static func markEdits(restoring before: [LocalDate: HabitMark], from now: [LocalDate: HabitMark]) -> [TaskEdit] {
        Set(before.keys).union(now.keys).sorted()
            .filter { before[$0] != now[$0] }
            .map { .mark(before[$0], on: $0) }
    }

    private static func habitEdits(restoring before: HabitOptions, from now: HabitOptions) -> [TaskEdit] {
        let fields: [(Bool, TaskEdit)] = [
            (before.color != now.color, .habitColor(before.color)),
            (before.harmful != now.harmful, .harmful(before.harmful)),
            (before.repeatable != now.repeatable, .repeatable(before.repeatable)),
            (before.showInToday != now.showInToday, .showInToday(before.showInToday)),
            (before.timeOfDay != now.timeOfDay, .timeOfDay(before.timeOfDay)),
            (before.twiceADay != now.twiceADay, .twiceADay(before.twiceADay)),
            (before.twiceCountsDouble != now.twiceCountsDouble, .twiceCountsDouble(before.twiceCountsDouble)),
            (before.weeklyGoal != now.weeklyGoal, .weeklyGoal(before.weeklyGoal)),
            (before.allowedSkips != now.allowedSkips, .allowedSkips(before.allowedSkips)),
        ]
        return fields.filter(\.0).map(\.1)
    }
}
