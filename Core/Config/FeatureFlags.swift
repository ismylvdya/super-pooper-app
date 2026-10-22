import Foundation

/// Every feature can be switched off with one flag in `feature-flags.json`.
struct FeatureFlags: Codable, Hashable, Sendable {
    var autoPromote: Bool
    var morningReviewAutoOpen: Bool
    var notifications: Bool
    var habitNotificationActions: Bool
    var reminders: Bool
    var eventLinks: Bool
    var widgetSnapshot: Bool
    var problemBadge: Bool
    var backups: Bool
    var haptics: Bool
    var syncBanner: Bool
    var archive: Bool
    var backgroundRefresh: Bool
}
