import Foundation

/// What a timeline shows, one rule for the app, the widget and the settings preview: hours around a moment, a fixed
/// range of the day, or two fixed halves side by side.
enum TimelineSpan: Hashable, Sendable {
    struct Range: Hashable, Sendable {
        let start: LocalTime
        let end: LocalTime
    }

    /// Caps on the hours around now (the widget has room for fewer).
    struct Limits: Hashable, Sendable {
        var hoursBefore = Int.max
        var hoursAfter = Int.max
        /// Before and after together.
        var hours = Int.max
    }

    case aroundNow(hoursBefore: Int, hoursAfter: Int)
    case range(Range)
    case halves(Range, Range)

    /// The hours around now within `limits`; at least one hour after now.
    static func aroundNow(hoursBefore: Int, hoursAfter: Int, limits: Limits) -> TimelineSpan {
        let before = min(hoursBefore, limits.hoursBefore)
        let after = max(min(hoursAfter, limits.hoursAfter, limits.hours - before), 1)
        return .aroundNow(hoursBefore: before, hoursAfter: after)
    }
}

extension TimelineWindow {
    /// The window or windows of `span` around `moment` (now, or the anchor hour of another day), never past the ends of
    /// the logical day of `context`: the timeline shows that day, and the hours after its boundary belong to the next
    /// one (the widget at 23:00 ends at 04:00, not at 05:00).
    static func windows(_ span: TimelineSpan, around moment: Date, context: DayContext) -> [TimelineWindow] {
        let windows: [TimelineWindow]
        switch span {
        case .aroundNow(let before, let after):
            windows = [.rolling(now: moment, hoursBefore: before, hoursAfter: after, calendar: context.calendar)]
        case .range(let range):
            windows = [.fixed(start: range.start, end: range.end, context: context)]
        case .halves(let first, let second):
            windows = [first, second].map { .fixed(start: $0.start, end: $0.end, context: context) }
        }
        return windows.map { $0.within(context.dayStart, context.dayEnd) }
    }

    /// Cut to `start`…`end`; a window wholly outside them is left as it is (there is nothing of the day to show).
    private func within(_ start: Date, _ end: Date) -> TimelineWindow {
        let cut = TimelineWindow(start: max(self.start, start), end: min(self.end, end))
        return cut.end > cut.start ? cut : self
    }
}
