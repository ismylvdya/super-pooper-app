import Foundation
@testable import SuperPooperApp

/// A clock the test moves by hand.
final class SettableClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) { current = start }

    var now: Date {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}
