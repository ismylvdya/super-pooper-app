import Foundation

/// User settings (`settings.json` in the App Group, merged over bundled `defaults.json`,
/// so settings written by an older version get defaults for new fields).
struct AppSettings: Codable, Equatable, Sendable {
    struct Vault: Codable, Equatable, Sendable {
        var tasksFolder: String
        var taskTag: String
        var trashFolder: String
        /// The Obsidian vault the TaskNotes folder belongs to and the folder's path inside it, for
        /// "Open in Obsidian" links (the app itself only sees the chosen folder).
        var obsidianVault: String
        var obsidianPathPrefix: String
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
        /// The user's order of the pool rules (raw names); empty = `sort.json`.
        var criteria: [String]
    }

    /// Where the pool and the timeline sit on Today.
    enum TodayArrangement: String, Codable, CaseIterable, Sendable {
        /// Pool on top, timeline below.
        case stacked
        /// Pool on the left, timeline on the right; both use the full height.
        case sideBySide
        /// The pool and the timeline as two full-screen pages; each shows the edge of the other (app only).
        case paged

        /// What the widget can show: it has no pages, so it gets the side-by-side arrangement instead.
        var forWidget: TodayArrangement { self == .paged ? .sideBySide : self }
    }

    struct Today: Codable, Equatable, Sendable {
        var arrangement: TodayArrangement
        /// The widget's own arrangement (vertical or horizontal), independent from the app's.
        var widgetArrangement: TodayArrangement
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
        /// The bell of blocks that will alert: size in points and opacity.
        var bellSize: Double
        var bellOpacity: Double
        /// Which kinds of entries the timeline shows.
        var shown: TimelineFilter
    }

    struct Notifications: Codable, Equatable, Sendable {
        var enabled: Bool
    }

    struct Onboarding: Codable, Equatable, Sendable {
        var completed: Bool
    }

    struct Habits: Codable, Equatable, Sendable {
        /// The user's order of the habit list (names); habits not in it follow alphabetically.
        var order: [String]
        /// "Show in Today" of a newly created habit.
        var showInTodayByDefault: Bool
        /// The order of the morning and evening routines in the pool (habit names).
        var morningRoutine: [String]
        var eveningRoutine: [String]
    }

    struct Clock: Codable, Equatable, Sendable {
        /// IANA time zone shown by the Clock tab and the Lock Screen widget.
        var timeZone: String
        /// Text before the time in the Lock Screen widget.
        var prefix: String
    }

    struct Appearance: Codable, Equatable, Sendable {
        /// Opacity of done tasks and past events in the pool, the timeline and the widget.
        var pastOpacity: Double
    }

    var vault: Vault
    var today: Today
    var sources: Sources
    var day: Day
    var pool: Pool
    var timeline: Timeline
    var notifications: Notifications
    var onboarding: Onboarding
    var habits: Habits
    var clock: Clock
    var appearance: Appearance
    /// Color overrides by token name (`task`, `habit`, `past`, …) as `#RRGGBB`; empty = tokens.json.
    var colors: [String: String]
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
        case .sideBySide, .paged: timeline.range == .wholeDay ? .wholeDay : .aroundNow
        }
    }

    /// The pool shows a fixed number of rows only when it sits above the timeline.
    var poolUsesVisibleCount: Bool { today.arrangement == .stacked }
}

extension AppSettings.Timeline {
    /// Length of the longer half of the day, in hours (two-halves layout scale).
    var halvesLongestHours: Double {
        func hours(_ range: AppSettings.TimeRange) -> Double {
            let minutes = range.end.minutesSinceMidnight - range.start.minutesSinceMidnight
            return Double(minutes > 0 ? minutes : minutes + 24 * 60) / 60
        }
        return max(hours(firstHalf), hours(secondHalf))
    }
}
