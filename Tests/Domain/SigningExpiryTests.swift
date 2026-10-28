import Foundation
import Testing
@testable import SuperPooperApp

/// The signature warning comes a day before the signature runs out, and never for a past time or no signature.
struct SigningExpiryTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func theWarningComesBeforeTheExpiration() {
        let expiration = now.addingTimeInterval(3 * 24 * 3600)
        #expect(SigningExpiry.warningDate(expiration: expiration, leadHours: 24, now: now) == expiration.addingTimeInterval(-24 * 3600))
    }

    @Test func noWarningWhenItIsTooLateOrThereIsNoSignature() {
        #expect(SigningExpiry.warningDate(expiration: now.addingTimeInterval(3600), leadHours: 24, now: now) == nil)
        #expect(SigningExpiry.warningDate(expiration: nil, leadHours: 24, now: now) == nil)
    }
}
