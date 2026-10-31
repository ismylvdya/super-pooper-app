import Foundation

/// The Today / Tomorrow chips of a task: at most one is on, and it stands for a `due` on that day.
enum QuickDue: CaseIterable, Sendable {
    case today
    case tomorrow

    func day(from today: LocalDate) -> LocalDate {
        switch self {
        case .today: today
        case .tomorrow: today.adding(days: 1)
        }
    }

    /// The chip that matches the task's logical day, if any (01:00 tonight is still today).
    static func selection(of due: TaskDue?, context: DayContext) -> QuickDue? {
        guard let due else { return nil }
        return allCases.first { $0.day(from: context.today) == context.logicalDay(of: due) }
    }

    /// Tapping a chip: an unselected one moves the task to its day (keeping the time), the selected one clears it.
    static func toggling(_ chip: QuickDue, due: TaskDue?, context: DayContext) -> TaskDue? {
        if selection(of: due, context: context) == chip { return nil }
        return context.due(onLogicalDay: chip.day(from: context.today), time: due?.time)
    }

    /// The chip of a note as written, judged on the phone's day (a time kept in a zone of its own is moved first).
    static func selection(of task: TaskNote, context: DayContext) -> QuickDue? {
        selection(of: ZonedTimes.local(task, calendar: context.calendar, today: context.today).due, context: context)
    }

    /// Tapping a chip on a note as written: the day is chosen on the phone's clock, the `due` written in the note's zone.
    static func toggling(_ chip: QuickDue, task: TaskNote, context: DayContext) -> TaskDue? {
        let local = ZonedTimes.local(task, calendar: context.calendar, today: context.today)
        return ZonedTimes.stored(toggling(chip, due: local.due, context: context), of: task, calendar: context.calendar)
    }
}
