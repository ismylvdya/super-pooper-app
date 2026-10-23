import Foundation

/// The top switch of a task page: a one-off task or a repeating habit.
enum TaskKind: Hashable, CaseIterable, Sendable {
    case task, habit

    /// Field changes for turning `note` into this kind. Habit marks stay in the note when it goes back to a task.
    func changes(for note: TaskNote, today: LocalDate) -> [TaskFieldChange] {
        switch self {
        case .habit:
            guard !note.isHabit else { return [] }
            let times = note.due?.time.map { [$0] } ?? []
            return [.status(.habit), .highPriority(false), .due(nil), .completedDate(nil),
                    .recurrence(note.recurrenceRaw ?? RecurrenceDraft(start: today).raw), .reminderTimes(times)]
        case .task:
            guard note.isHabit else { return [] }
            return [.status(.thisWeek), .recurrence(nil), .reminderTimes([])]
        }
    }
}
