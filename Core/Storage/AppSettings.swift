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
        /// How solid the outline of a task picked in Select mode is.
        var selectionOutlineOpacity: Double
        /// The order of the chips in task rows (raw names of `RowChipKind`).
        var chipOrder: [String]
        /// How a high-priority task stands out in the pool and on the timeline.
        var highPriorityLook: HighPriorityLook
        /// How far a started task's fill reaches across its plate, as a share of its width.
        var startedFillLength: Double
    }

    /// How a high-priority task stands out: the priority icon before its name, or its whole plate in a soft red.
    enum HighPriorityLook: String, Codable, CaseIterable, Sendable {
        case leadingIcon
        case fill
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
        /// The app turned sideways has its own arrangement, independent from the upright one.
        var landscapeArrangement: TodayArrangement
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
        /// The words of the signature's hourly reminder; empty = the bundled ones.
        var signingMessage: String
        /// A notification snoozed from its button comes again this many minutes later.
        var snoozeMinutes: Int
    }

    struct Onboarding: Codable, Equatable, Sendable {
        var completed: Bool
    }

    struct Habits: Codable, Equatable, Sendable {
        /// The user's order of the habit list (names); habits not in it follow alphabetically.
        var order: [String]
        /// "Show in Today" of a newly created habit (on by default; the old `showInTodayByDefault`, which was off,
        /// is not read any more).
        var showNewHabitsInToday: Bool
        /// The own color (`#RRGGBB`) a newly created habit gets; black unless the user picks another.
        var newHabitColor: String
        /// The order of the morning and evening routines in the pool (habit names).
        var morningRoutine: [String]
        var eveningRoutine: [String]
        /// Opacity of the ring of a habit's day not done or done partly (on its page's grid, in the Habits list, the widget).
        var ringOpacity: Double
        /// A repeatable task's page shows the history grid and the statistics too, as a habit's does.
        var repeatableShowsHistory: Bool
        /// Habit notifications carry a picture at the right at all.
        var showsNotificationPicture: Bool
        /// The habit symbol on a notification in the habit's own color (when it has one) instead of the habits' color.
        var notificationUsesHabitColor: Bool

        /// Where the order of one routine is kept: the one place that ties a part of the day to its setting.
        static func routine(_ part: HabitTimeOfDay) -> WritableKeyPath<Habits, [String]> {
            switch part {
            case .morning: \.morningRoutine
            case .evening: \.eveningRoutine
            }
        }

        /// Whether the page of `task` shows its history grid and statistics: always a habit's, a repeatable task's as set.
        func showsHistory(of task: TaskItem) -> Bool { !task.habit.repeatable || repeatableShowsHistory }

        /// The orders of all routines, for the day.
        var routines: HabitRoutines {
            HabitRoutines(morning: morningRoutine, evening: eveningRoutine)
        }
    }

    struct Clock: Codable, Equatable, Sendable {
        /// IANA time zone shown by the Clock tab and the Lock Screen widget.
        var timeZone: String
        /// Text before the time in the Lock Screen widget.
        var prefix: String
    }

    struct Lists: Codable, Equatable, Sendable {
        /// The id of the Lists icon picked (`lists.json` → `icons`).
        var icon: String
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
    var lists: Lists
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
    /// The app's timeline, in the app's own arrangement.
    var timelineMode: TimelineMode { timelineMode(in: today.arrangement) }

    /// The timeline in an arrangement: the app's, or the widget's own (`TodayWidgetView`).
    func timelineMode(in arrangement: TodayArrangement) -> TimelineMode {
        switch arrangement {
        case .stacked: timeline.layout == .twoColumns ? .halves : .aroundNow
        case .sideBySide, .paged: timeline.range == .wholeDay ? .wholeDay : .aroundNow
        }
    }

    /// What the app's timeline shows by these settings; `limits` cap the hours around now.
    func timelineSpan(limits: TimelineSpan.Limits = TimelineSpan.Limits()) -> TimelineSpan {
        timelineSpan(in: today.arrangement, limits: limits)
    }

    /// What a timeline in that arrangement shows by these settings.
    func timelineSpan(in arrangement: TodayArrangement, limits: TimelineSpan.Limits = TimelineSpan.Limits()) -> TimelineSpan {
        func range(_ range: TimeRange) -> TimelineSpan.Range { TimelineSpan.Range(start: range.start, end: range.end) }
        switch timelineMode(in: arrangement) {
        case .aroundNow: return .aroundNow(hoursBefore: timeline.hoursBefore, hoursAfter: timeline.hoursAfter, limits: limits)
        case .wholeDay: return .range(range(timeline.wholeDay))
        case .halves: return .halves(range(timeline.firstHalf), range(timeline.secondHalf))
        }
    }

    /// The app's pool shows a fixed number of rows only when it sits above the timeline.
    var poolUsesVisibleCount: Bool { poolUsesVisibleCount(in: today.arrangement) }

    func poolUsesVisibleCount(in arrangement: TodayArrangement) -> Bool { arrangement == .stacked }

    /// A change that moves the day or what is planned in it: the day boundary and the energy hour, notifications on or
    /// off, other calendars or lists, another folder. The notifications and the widget snapshot follow only those.
    func replansDay(comparedTo old: AppSettings) -> Bool {
        day != old.day || notifications != old.notifications || sources != old.sources || vault != old.vault
    }
}

