import Foundation

/// How close the end of the app's signature is, for the plate at the top of Settings.
struct SigningCountdown: Equatable, Sendable {
    /// Green while there are days to spare, yellow on the day before the last, red on the last day.
    enum Level: Equatable, Sendable {
        case ahead
        case soon
        case urgent
    }

    /// Whole days left, or hours on the last day; `expired` once the time is up.
    enum Remaining: Equatable, Sendable {
        case days(Int)
        case hours(Int)
        case expired
    }

    let level: Level
    let remaining: Remaining
}
