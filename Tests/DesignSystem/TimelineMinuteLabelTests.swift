import Testing
import UIKit
@testable import SuperPooperApp

/// The ":15" of a zoomed-in timeline and of a drag's landing spot: one font, 1.25 times smaller than the hours.
@MainActor
struct TimelineMinuteLabelTests {
    @Test func minutesAreSmallerThanTheHoursByAQuarter() {
        let tokens = TestConfig.tokens
        let ratio = tokens.uiFont(.timelineHour).pointSize / tokens.uiFont(.timelineMinutes).pointSize
        #expect(abs(ratio - 1.25) < 0.02, "the scaled size is rounded a little")
    }
}
