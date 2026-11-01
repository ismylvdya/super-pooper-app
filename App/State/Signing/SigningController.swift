import Foundation
import Observation

/// How long the app's signature has left, for the plate at the top of Settings. Worked out again when asked (Settings
/// shows, the app becomes active), so the count moves on while the app stays open.
@MainActor
@Observable
final class SigningController {
    private(set) var countdown: SigningCountdown?
    @ObservationIgnored private let signature: AppSignatureReading
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let rules: SigningPlateRules

    init(signature: AppSignatureReading, clock: Clock, rules: SigningPlateRules) {
        self.signature = signature
        self.clock = clock
        self.rules = rules
        refresh()
    }

    func refresh() {
        let countdown = SigningExpiry.countdown(expiration: signature.expiration(), now: clock.now, rules: rules)
        if countdown != self.countdown { self.countdown = countdown }
    }
}
