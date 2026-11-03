import Foundation

/// Where a dragged "+" (or a hold on the empty timeline) put the item still to be made: a moment of a timeline, or a
/// spot among the pool's rows and in one of its sections.
enum NewItemPlacement: Hashable, Sendable {
    /// The day and time of the spot, already on the timeline's drop step.
    case timeline(day: LocalDate, time: LocalTime)
    /// `order`: the pool with `gap` where it landed; `section`: the section of the spot (nil: a pool without sections).
    case pool(order: [String], section: String?, day: LocalDate)

    /// The pool's id for the room the item takes until it is made; no note can be called so (a note's name is a file's, never with `/`).
    static let gap = "/new-item"

    /// A spot on a timeline by its moment, on the phone's clock.
    static func timeline(at moment: Date, calendar: Calendar) -> NewItemPlacement {
        .timeline(day: LocalDate(moment, in: calendar), time: LocalTime(moment, in: calendar))
    }

    /// What the placement presets on the new item: a task's date and time, a habit's reminder time.
    func presets(_ kind: NewItemSeed.Kind) -> [TaskEdit] {
        guard case .timeline(let day, let time) = self else { return [] }
        switch kind {
        case .task: return [.due(TaskDue(day: day, time: time))]
        case .habit: return [.reminderTimes([time])]
        }
    }

    /// The pool's order once the item is made as `name`: the gap becomes it.
    func poolOrder(named name: String) -> [String]? {
        guard case .pool(let order, _, _) = self else { return nil }
        return order.map { $0 == Self.gap ? name : $0 }
    }
}
