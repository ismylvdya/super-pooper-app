import Foundation
@testable import SuperPooperApp

/// A debounce wait the test ends by opening the gate; a wait cancelled meanwhile throws when it ends, as a sleep would.
struct GatedDelay: Delay {
    let gate = AsyncGate()

    func wait(_ seconds: Double) async throws {
        await gate.pass()
        try Task.checkCancellation()
    }
}

/// A debounce wait that is over at once.
struct NoDelay: Delay {
    func wait(_ seconds: Double) async throws {
        try Task.checkCancellation()
    }
}
