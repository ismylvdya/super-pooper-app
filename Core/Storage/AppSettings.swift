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

    enum TimelineLayout: String, Codable, CaseIterable, Sendable {
        case oneColumn
        case twoColumns
    }

    struct TimeRange: Codable, Equatable, Sendable {
        var start: LocalTime
        var end: LocalTime
    }

    struct Timeline: Codable, Equatable, Sendable {
        var layout: TimelineLayout
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
    var sources: Sources
    var day: Day
    var pool: Pool
    var timeline: Timeline
    var notifications: Notifications
    var onboarding: Onboarding
}
