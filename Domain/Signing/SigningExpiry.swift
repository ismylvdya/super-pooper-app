import Foundation

/// The app runs on a signature that runs out (Xcode's free team after 7 days, AltStore's after its own term); a
/// warning comes `leadHours` before that, so there is time to re-sign and, meanwhile, to turn the Calendar and
/// Reminders notifications back on.
enum SigningExpiry {
    /// The signature runs out within the warning time (and has not yet).
    static func isSoon(expiration: Date?, leadHours: Double, now: Date) -> Bool {
        guard let expiration, expiration > now else { return false }
        return expiration.timeIntervalSince(now) <= leadHours * 3600
    }

    /// When to warn; nil when the signature never runs out or the warning time has passed.
    static func warningDate(expiration: Date?, leadHours: Double, now: Date) -> Date? {
        guard let expiration else { return nil }
        let warning = expiration.addingTimeInterval(-leadHours * 3600)
        return warning > now ? warning : nil
    }
}
