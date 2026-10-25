import Foundation

/// Another day than today (swiped to on Today); which tasks it has is decided by `DayBuilder`.
enum OtherDay {
    /// "Now" inside another day: the hour the timeline centres on (no cursor is drawn).
    static func moment(of day: LocalDate, context: DayContext, anchor: LocalTime) -> Date {
        context.moment(anchor, onLogicalDay: day)
    }
}
