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

    /// The chip that matches the task's date, if any.
    static func selection(of due: TaskDue?, today: LocalDate) -> QuickDue? {
        guard let due else { return nil }
        return allCases.first { $0.day(from: today) == due.day }
    }

    /// Tapping a chip: an unselected one moves the date to its day (keeping the time), the selected one clears it.
    static func toggling(_ chip: QuickDue, due: TaskDue?, today: LocalDate) -> TaskDue? {
        if selection(of: due, today: today) == chip { return nil }
        return TaskDue(day: chip.day(from: today), time: due?.time)
    }
}
