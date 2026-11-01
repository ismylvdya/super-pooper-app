import Foundation
import Testing
@testable import SuperPooperApp

/// The signature plate says what is left in words, singular and plural from the string catalog.
struct SigningCountdownTextTests {
    @Test func daysAndHoursHaveTheirPluralForms() {
        #expect(SigningCountdownText.remaining(.days(1)) == "1 day left")
        #expect(SigningCountdownText.remaining(.days(5)) == "5 days left")
        #expect(SigningCountdownText.remaining(.hours(1)) == "1 hour left")
        #expect(SigningCountdownText.remaining(.hours(23)) == "23 hours left")
    }

    @Test func anEndedSignatureSaysSo() {
        #expect(SigningCountdownText.remaining(.expired) == "Expired")
    }
}
