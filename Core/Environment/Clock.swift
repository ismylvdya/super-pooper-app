import Foundation

/// Source of "now". Logic never calls `Date()` directly.
protocol Clock: Sendable {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

/// A clock shifted to a chosen moment that keeps ticking (DEBUG `-SPNow`, previews).
struct ShiftedClock: Clock {
    let offset: TimeInterval

    init(startingAt start: Date, reference: Date = Date()) {
        offset = start.timeIntervalSince(reference)
    }

    var now: Date { Date().addingTimeInterval(offset) }
}

/// A clock frozen at one moment (tests).
struct FixedClock: Clock {
    let now: Date
}
