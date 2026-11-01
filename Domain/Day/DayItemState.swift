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
