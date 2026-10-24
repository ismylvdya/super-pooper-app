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
        let noteExtension: String
    }

    struct Backups: Codable, Hashable, Sendable {
        let keepCount: Int
    }

    struct Timeline: Codable, Hashable, Sendable {
        /// How often "now" moves and chains are re-laid out.
        let refreshSeconds: Double
        /// Upper bound for the hours shown in the one-column layout.
        let maxHoursAfter: Int
    }

    struct Widgets: Codable, Hashable, Sendable {
        let refreshMinutes: Int
        let entryCount: Int
        /// Weeks in the habit widget.
        let habitGridWeeksSmall: Int
        /// Hours the one-column timeline shows in the Today widget.
        let timelineHours: Int
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

    let day: DayRules
    let timeEstimates: [EstimateOption]
    let notifications: Notifications
    let eventLinks: EventLinks
    let vault: Vault
    let backups: Backups
    let timeline: Timeline
    let widgets: Widgets
    let habits: Habits
    let pool: Pool
}

/// Order of the pool sort criteria (`sort.json`).
struct SortConfig: Codable, Hashable, Sendable {
    let pool: [PoolSortCriterion]
}
