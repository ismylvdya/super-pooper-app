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

    /// Which time an overdue item's notification comes (`OverdueRepeats`): 0 the first, then 1, 2… Of one item's shown
    /// notifications only the latest stays.
    static func round(_ identifier: String) -> Int {
        guard identifier.contains("again|") else { return 0 }
        // The fire time follows the last "@"; the round is the last part before it (a name may hold "@" or "|").
        let planned = identifier.lastIndex(of: "@").map { identifier[..<$0] } ?? identifier[...]
        return planned.split(separator: "|").last.flatMap { Int($0) } ?? 0
    }

    /// The identifier the notification was planned or sent late under: whether it may stay is decided by it.
    static func shown(_ identifier: String) -> String {
        isRestored(identifier) ? String(identifier.dropLast(restoredSuffix.count)) : identifier
    }
}
