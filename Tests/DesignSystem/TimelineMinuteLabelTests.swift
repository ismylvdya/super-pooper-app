import Testing
import UIKit
@testable import SuperPooperApp

/// The ":15" of a zoomed-in timeline and of a drag's landing spot: one font, about twice smaller than the hours.
@MainActor
struct TimelineMinuteLabelTests {
    @Test func minutesAreMuchSmallerThanTheHours() {
        let tokens = TestConfig.tokens
        let ratio = tokens.uiFont(.timelineHour).pointSize / tokens.uiFont(.timelineMinutes).pointSize
        #expect(ratio >= 1.5, "much smaller than the hours")
    }
}
