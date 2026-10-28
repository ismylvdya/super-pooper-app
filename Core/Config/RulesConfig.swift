import Foundation

/// Developer-tunable rules (`rules.json`), separate from the UI and from user settings.
struct RulesConfig: Codable, Hashable, Sendable {
    struct EstimateOption: Codable, Hashable, Sendable {
        let minutes: Int
        /// String Catalog key of the label.
        let label: String
    }

    struct Notifications: Codable, Hashable, Sendable {
        /// iOS keeps at most 64 pending local notifications.
        let limit: Int
        let horizonDays: Int
        /// The user's own picture for habit notifications, in the app group.
        let imageFile: String
    }

    struct EventLinks: Codable, Hashable, Sendable {
        /// Range of days searched when resolving `previous_event` / `next_event`.
        let resolveDaysBefore: Int
        let resolveDaysAfter: Int
        /// How many days ahead the event picker lists.
        let pickerDaysAhead: Int
        /// URL prefix that opens Apple Calendar on a date (seconds since 2001 are appended).
        let calendarAppURL: String
        /// URL prefix that opens a reminder in Apple Reminders (its identifier is appended).
        let remindersAppURL: String
    }

    struct Vault: Codable, Hashable, Sendable {
        let downloadTimeoutSeconds: Double
        /// While waiting for iCloud downloads, the files are checked this often.
        let downloadPollSeconds: Double
        let noteExtension: String
        /// The JSON file with the app's shared settings, next to the tasks folder.
        let settingsFile: String
        /// The older note with those settings, read until the file exists.
        let settingsNote: String
        /// Where done tasks are moved, next to the tasks folder; Obsidian and TaskNotes are set to skip it.
        let doneFolder: String
        /// Where Obsidian keeps its iCloud vaults: a folder under it names its vault and its path in it.
        let obsidianVaultsFolder: String
        /// The settings note is written this long after the last change.
        let settingsWriteDelaySeconds: Double
    }

    struct Backups: Codable, Hashable, Sendable {
        let keepCount: Int
    }

    struct Timeline: Codable, Hashable, Sendable {
        /// How often "now" moves and chains are re-laid out.
        let refreshSeconds: Double
        /// A Calendar or Reminders change made elsewhere is read this long after it is announced (they come in bursts).
        let externalChangeDelaySeconds: Double
        /// Upper bound for the hours shown in the one-column layout.
        let maxHoursAfter: Int
        /// Another day (swiped to on Today) is shown around this time.
        let otherDayAnchor: LocalTime
        /// A task dropped on the timeline lands on a multiple of this many minutes.
        let dropStepMinutes: Int
    }

    struct Widgets: Codable, Hashable, Sendable {
        let refreshMinutes: Int
        let entryCount: Int
        /// Weeks in the habit widget.
        let habitGridWeeksSmall: Int
        /// Hours the one-column timeline shows in the Today widget.
        let timelineHours: Int
        /// The widget timeline starts at most this many hours before now.
        let maxHoursBefore: Int
        /// Background refresh (vault, widgets, notifications) is asked for this often.
        let backgroundRefreshMinutes: Int
    }

    struct Habits: Codable, Hashable, Sendable {
        /// The habit page grid shows at least this many weeks, and reaches back to the start plus `historyExtraWeeks`.
        let historyMinimumWeeks: Int
        let historyExtraWeeks: Int
        /// Weeks one pull at the top of the history adds.
        let historyPullWeeks: Int
        /// Values a rule starts with when it is switched on.
        let defaultAllowedSkips: Int
        let defaultWeeklyGoal: Int
        let maxAllowedSkips: Int
        /// Bells under a habit's name in the Habits list (one per reminder, up to this many).
        let maxListBells: Int
    }

    /// Pool rows of long tasks are taller: extra title lines from this estimate on.
    struct Pool: Codable, Hashable, Sendable {
        struct ExtraLines: Codable, Hashable, Sendable {
            let minutes: Int
            let lines: Int
        }

        let extraLines: [ExtraLines]

        func extraLines(forEstimate minutes: Int) -> Int {
            extraLines.filter { minutes >= $0.minutes }.map(\.lines).max() ?? 0
        }
    }

    /// Ranges of the number controls on settings and note pages.
    struct Limits: Codable, Hashable, Sendable {
        struct Range: Codable, Hashable, Sendable {
            let min: Double
            let max: Double
            /// The slider step, when it has one.
            var step: Double?

            var closed: ClosedRange<Double> { min...max }

            /// The nearest step (unchanged without one).
            func snapped(_ value: Double) -> Double {
                guard let step, step > 0 else { return value }
                return (value / step).rounded() * step
            }
            var ints: ClosedRange<Int> { Int(min)...Int(max) }
        }

        let poolVisibleCount: Range
        let hoursBefore: Range
        let bellSize: Range
        let bellOpacity: Range
        let fontSize: Range
        let pastOpacity: Range
        let recurrenceInterval: Range
        let recurrenceCount: Range
        /// "Each" day number of a monthly repeat.
        let monthDay: Range
    }

    let day: DayRules
    let timeEstimates: [EstimateOption]
    let notifications: Notifications
    let eventLinks: EventLinks
    let vault: Vault
    let backups: Backups
    let timeline: Timeline
    let widgets: Widgets
    let habits: Habits
    /// Values a new date, time, reminder or repeat end starts from.
    struct Editing: Codable, Hashable, Sendable {
        let defaultTime: LocalTime
        /// A new habit reminder comes this long after the last one.
        let nextReminderGapMinutes: Int
        /// The note text is saved this long after typing stops.
        let noteSaveDelaySeconds: Double
        let repeatUntilDays: Int
        let repeatCount: Int
    }

    let pool: Pool
    let limits: Limits
    let editing: Editing
}

/// Order of the pool sort criteria (`sort.json`).
struct SortConfig: Codable, Hashable, Sendable {
    let pool: [PoolSortCriterion]
}
