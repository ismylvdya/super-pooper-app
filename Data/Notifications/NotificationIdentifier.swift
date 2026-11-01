import Foundation

/// Identifiers of the app's requests: a planned notification's own, a late alert sent at once (`|late`), and a
/// notification put back after it was swiped away (`|restored`), which never takes a pending request's place.
enum NotificationIdentifier {
    private static let lateSuffix = "|late"
    private static let restoredSuffix = "|restored"

    static func late(_ identifier: String) -> String { identifier + lateSuffix }

    static func restored(_ identifier: String) -> String {
        isRestored(identifier) ? identifier : identifier + restoredSuffix
    }

    static func isRestored(_ identifier: String) -> Bool { identifier.hasSuffix(restoredSuffix) }

    /// The identifier the notification was planned or sent late under: whether it may stay is decided by it.
    static func shown(_ identifier: String) -> String {
        isRestored(identifier) ? String(identifier.dropLast(restoredSuffix.count)) : identifier
    }
}
