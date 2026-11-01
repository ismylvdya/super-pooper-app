import Foundation
import Testing
@testable import SuperPooperApp

/// The app model works out the signature plate from the installed signature and the app clock, and again when asked
/// (Settings shows, the app becomes active).
@MainActor
struct SigningPlateTests {
    private let start = PreviewSamples.context.now

    @Test func thePlateCountsDownWhenItIsWorkedOutAgain() throws {
        let clock = SettableClock(start)
        let signature = FixedSignature(date: start.addingTimeInterval(30 * 3600))
        let model = try #require(PreviewModel.make(clock: clock, signature: signature)).model
        #expect(model.signingCountdown == SigningCountdown(level: .soon, remaining: .days(1)))
        clock.now = start.addingTimeInterval(10 * 3600)
        #expect(model.signingCountdown == SigningCountdown(level: .soon, remaining: .days(1)), "nothing moves until asked")
        model.refreshSigning()
        #expect(model.signingCountdown == SigningCountdown(level: .urgent, remaining: .hours(20)))
    }

    @Test func anUnknownSignatureHasNoPlate() throws {
        let model = try #require(PreviewModel.make(signature: FixedSignature(date: nil))).model
        model.refreshSigning()
        #expect(model.signingCountdown == nil)
    }
}

/// A clock the test moves by hand.
private final class SettableClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) { current = start }

    var now: Date {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}
