import Foundation

/// User settings (`settings.json` in the App Group, merged over bundled `defaults.json`,
/// so settings written by an older version get defaults for new fields).
struct AppSettings: Codable, Equatable, Sendable {
    struct Vault: Codable, Equatable, Sendable {
        var tasksFolder: String
        var taskTag: String
        var trashFolder: String
    }

    struct Sources: Codable, Equatable, Sendable {
        var anchorCalendarIDs: [String]
        var reminderListIDs: [String]
    }

    struct Day: Codable, Equatable, Sendable {
        var boundary: LocalTime
        var energyHour: LocalTime
    }

    struct Pool: Codable, Equatable, Sendable {
        var visibleCount: Int
    }

    /// Where the pool and the timeline sit on Today.
    enum TodayArrangement: String, Codable, CaseIterable, Sendable {
        /// Pool on top, timeline below.
        case stacked
        /// Pool on the left, timeline on the right; both use the full height.
        case sideBySide
    }

    struct Today: Codable, Equatable, Sendable {
        var arrangement: TodayArrangement
    }

    /// Stacked arrangement: one rolling column or two fixed halves.
    enum TimelineLayout: String, Codable, CaseIterable, Sendable {
        case oneColumn
        case twoColumns
    }

    /// Side-by-side arrangement: hours around now, or the whole day fitted into one column.
    enum TimelineRange: String, Codable, CaseIterable, Sendable {
        case aroundNow
        case wholeDay
    }

    struct TimeRange: Codable, Equatable, Sendable {
        var start: LocalTime
        var end: LocalTime
    }

    struct Timeline: Codable, Equatable, Sendable {
        var layout: TimelineLayout
        var range: TimelineRange
        var wholeDay: TimeRange
        var hoursBefore: Int
        var hoursAfter: Int
        var firstHalf: TimeRange
        var secondHalf: TimeRange
        var eventFontSize: Double
        var taskFontSize: Double
    }

    struct Notifications: Codable, Equatable, Sendable {
        var enabled: Bool
    }

    struct Onboarding: Codable, Equatable, Sendable {
        var completed: Bool
    }

    var vault: Vault
    var today: Today
    var sources: Sources
    var day: Day
    var pool: Pool
    var timeline: Timeline
    var notifications: Notifications
    var onboarding: Onboarding
}

/// What the timeline shows, given the arrangement and its settings.
enum TimelineMode: Equatable, Sendable {
    /// One scrolling column from "now − before" to "now + after".
    case aroundNow
    /// One column with the whole day range, fitted to the height.
    case wholeDay
    /// Two fixed halves of the day side by side (stacked arrangement only).
    case halves
}

extension AppSettings {
    var timelineMode: TimelineMode {
        switch today.arrangement {
        case .stacked: timeline.layout == .twoColumns ? .halves : .aroundNow
        case .sideBySide: timeline.range == .wholeDay ? .wholeDay : .aroundNow
        }
    }

    /// The pool shows a fixed number of rows only when it sits above the timeline.
    var poolUsesVisibleCount: Bool { today.arrangement == .stacked }
}
