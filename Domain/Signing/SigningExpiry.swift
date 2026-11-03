import Foundation

/// The app runs on a signature that runs out (Xcode's free team after 7 days, AltStore's after its own term); a
/// warning comes `leadHours` before that, so there is time to re-sign and, meanwhile, to turn the Calendar and
/// Reminders notifications back on. Shortly before, a plate at the top of Settings counts down to it (`countdown`).
enum SigningExpiry {
    private static let secondsPerDay: TimeInterval = 24 * 3600
    private static let secondsPerHour: TimeInterval = 3600

    /// The signature runs out within the warning time (and has not yet).
    static func isSoon(expiration: Date?, leadHours: Double, now: Date) -> Bool {
        guard let expiration, expiration > now else { return false }
        return expiration.timeIntervalSince(now) <= leadHours * secondsPerHour
    }

    /// When to warn; nil when the signature never runs out or the warning time has passed.
    static func warningDate(expiration: Date?, leadHours: Double, now: Date) -> Date? {
        guard let expiration else { return nil }
        let warning = expiration.addingTimeInterval(-leadHours * secondsPerHour)
        return warning > now ? warning : nil
    }

    /// When to remind: every `everyHours` from `leadHours` before the end up to the end, the moments still ahead.
    static func reminderDates(expiration: Date?, leadHours: Double, everyHours: Double, now: Date) -> [Date] {
        guard let expiration, everyHours > 0 else { return [] }
        let start = expiration.addingTimeInterval(-leadHours * secondsPerHour)
        return stride(from: start.timeIntervalSinceReferenceDate, to: expiration.timeIntervalSinceReferenceDate, by: everyHours * secondsPerHour)
            .map(Date.init(timeIntervalSinceReferenceDate:))
            .filter { $0 > now }
    }

    /// The plate for a signature ending at `expiration`; nil when it is unknown or further away than the plate shows.
    /// Days are whole days still left (2 days 20 hours is 2 days); the hours of the last day are rounded up, so the
    /// plate never says 0 hours while some time is left.
    static func countdown(expiration: Date?, now: Date, rules: SigningPlateRules) -> SigningCountdown? {
        guard let expiration else { return nil }
        let left = expiration.timeIntervalSince(now)
        guard left <= rules.showWithinDays * secondsPerDay else { return nil }
        guard left > 0 else { return SigningCountdown(level: .urgent, remaining: .expired) }
        if left < rules.urgentWithinDays * secondsPerDay {
            return SigningCountdown(level: .urgent, remaining: .hours(Int((left / secondsPerHour).rounded(.up))))
        }
        let level: SigningCountdown.Level = left < rules.soonWithinDays * secondsPerDay ? .soon : .ahead
        return SigningCountdown(level: level, remaining: .days(Int(left / secondsPerDay)))
    }
}
