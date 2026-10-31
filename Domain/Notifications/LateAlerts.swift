import Foundation

/// Alerts whose time passed without a notification, sent right away (as the old Calendar Enhancer did):
/// an item moved earlier so that its alert time is already over, or an alert added to an event of today (the logical
/// day: 23:30 still counts at 01:00) that has already started. `pending` is what was still upcoming at the previous
/// sync (key → time); `known` all keys seen then (nil on the very first sync, which only remembers).
enum LateAlerts {
    static func due(_ alerts: [PlannedNotification], pending: [String: Date], known: Set<String>?,
                    context: DayContext) -> [PlannedNotification] {
        let now = context.now
        return alerts.filter { alert in
            guard alert.fireDate <= now, alert.kind != .habit else { return false }
            if let was = pending[alert.key], was > now, alert.fireDate < was { return true }
            guard let known, !known.contains(alert.key), let start = alert.start, start <= now,
                  context.logicalDay(of: start) == context.today else { return false }
            return true
        }
    }
}
