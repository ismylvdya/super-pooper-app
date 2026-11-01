import Foundation

/// How long the app's signature has left, in words: "5 days left", "1 day left", "3 hours left", "Expired".
enum SigningCountdownText {
    static func remaining(_ remaining: SigningCountdown.Remaining) -> String {
        switch remaining {
        case .days(let days): String(localized: "settings.signing.days \(days)")
        case .hours(let hours): String(localized: "settings.signing.hours \(hours)")
        case .expired: String(localized: "settings.signing.expired")
        }
    }
}
