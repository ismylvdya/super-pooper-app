import Foundation

/// The wait before debounced work runs (a note written after typing stops, a burst of Calendar changes read once).
/// Tests put in a wait they end themselves instead of sleeping.
protocol Delay: Sendable {
    /// Returns after `seconds`; throws when the waiting task is cancelled.
    func wait(_ seconds: Double) async throws
}

struct SleepDelay: Delay {
    func wait(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}
