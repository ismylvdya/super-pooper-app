import Foundation
import Testing
@testable import SuperPooperApp

/// The plate at the top of Settings: none while more than 7 days are left, green from 7 days down to 2, yellow under 2
/// days (1 day left), red under 1 day with the hours instead of days, and red "expired" once the time is up.
struct SigningCountdownTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let day: TimeInterval = 24 * 3600
    private let hour: TimeInterval = 3600
    private let second: TimeInterval = 1

    private func countdown(left: TimeInterval, rules: SigningPlateRules = TestConfig.rules.signingPlate) -> SigningCountdown? {
        SigningExpiry.countdown(expiration: now.addingTimeInterval(left), now: now, rules: rules)
    }

    @Test func theThresholdsAreTheRules() {
        #expect(TestConfig.rules.signingPlate == SigningPlateRules(showWithinDays: 7, soonWithinDays: 2, urgentWithinDays: 1))
    }

    @Test func moreThanSevenDaysOrAnUnknownEndShowNoPlate() {
        #expect(countdown(left: 7 * day + second) == nil)
        #expect(countdown(left: 30 * day) == nil)
        #expect(SigningExpiry.countdown(expiration: nil, now: now, rules: TestConfig.rules.signingPlate) == nil)
    }

    @Test func sevenDaysExactlyIsGreen() {
        #expect(countdown(left: 7 * day) == SigningCountdown(level: .ahead, remaining: .days(7)))
        #expect(countdown(left: 7 * day - second) == SigningCountdown(level: .ahead, remaining: .days(6)))
    }

    @Test func twoDaysExactlyIsStillGreenAndJustUnderIsYellow() {
        #expect(countdown(left: 2 * day) == SigningCountdown(level: .ahead, remaining: .days(2)))
        #expect(countdown(left: 2 * day - second) == SigningCountdown(level: .soon, remaining: .days(1)))
    }

    @Test func oneDayExactlyIsYellowAndJustUnderIsRedInHours() {
        #expect(countdown(left: 1 * day) == SigningCountdown(level: .soon, remaining: .days(1)))
        #expect(countdown(left: 1 * day - second) == SigningCountdown(level: .urgent, remaining: .hours(24)))
    }

    /// Hours are rounded up: the plate never says 0 hours while time is left.
    @Test func theLastDayCountsHours() {
        #expect(countdown(left: 5 * hour) == SigningCountdown(level: .urgent, remaining: .hours(5)))
        #expect(countdown(left: 5 * hour + second) == SigningCountdown(level: .urgent, remaining: .hours(6)))
        #expect(countdown(left: second) == SigningCountdown(level: .urgent, remaining: .hours(1)))
    }

    @Test func zeroAndLaterIsExpired() {
        #expect(countdown(left: 0) == SigningCountdown(level: .urgent, remaining: .expired))
        #expect(countdown(left: -hour) == SigningCountdown(level: .urgent, remaining: .expired))
    }

    /// Other rules move the boundaries with them.
    @Test func theBoundariesFollowTheRules() {
        let rules = SigningPlateRules(showWithinDays: 3, soonWithinDays: 1.5, urgentWithinDays: 0.5)
        #expect(countdown(left: 3 * day + second, rules: rules) == nil)
        #expect(countdown(left: 3 * day, rules: rules) == SigningCountdown(level: .ahead, remaining: .days(3)))
        #expect(countdown(left: 1.5 * day - second, rules: rules) == SigningCountdown(level: .soon, remaining: .days(1)))
        #expect(countdown(left: 12 * hour - second, rules: rules) == SigningCountdown(level: .urgent, remaining: .hours(12)))
    }
}
