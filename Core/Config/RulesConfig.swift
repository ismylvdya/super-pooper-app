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
        let habitGridWeeksSmall: Int
        let habitGridWeeksMedium: Int
    }

    let day: DayRules
    let timeEstimates: [EstimateOption]
    let notifications: Notifications
    let eventLinks: EventLinks
    let vault: Vault
    let backups: Backups
    let timeline: Timeline
    let widgets: Widgets
}

/// Order of the pool sort criteria (`sort.json`).
struct SortConfig: Codable, Hashable, Sendable {
    let pool: [PoolSortCriterion]
}
