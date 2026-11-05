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
    static func selection(of task: TaskItem, context: DayContext) -> QuickDue? {
        selection(of: ZonedTimes.local(task, calendar: context.calendar, today: context.today).due, context: context)
    }

    /// Tapping a chip on a note as written: the day is chosen on the phone's clock, the `due` written in the note's zone.
    static func toggling(_ chip: QuickDue, task: TaskItem, context: DayContext) -> TaskDue? {
        let local = ZonedTimes.local(task, calendar: context.calendar, today: context.today)
        return ZonedTimes.stored(toggling(chip, due: local.due, context: context), of: task, calendar: context.calendar)
    }
}

/// The date chip beside Today and Tomorrow: it opens the date sheet and names what the two cannot — a day other than
/// today or tomorrow, and a time on any day.
enum DateChip {
    /// The day the chip names; nil without a due or with one on a day the chips beside it name.
    static func title(for due: TaskDue?, context: DayContext) -> LocalDate? {
        guard let due, QuickDue.selection(of: due, context: context) == nil else { return nil }
        return due.day
    }

    /// The day and time the chip shows: as the note has them, in its own zone if it has one, as the date sheet does. A zone
    /// added to a time does not change the time.
    static func shown(of task: TaskItem, context: DayContext) -> (day: LocalDate?, time: LocalTime?) {
        (title(for: task.due, context: context), task.due?.time)
    }
}
