import Testing
import UIKit
@testable import SuperPooperApp

/// The ":15" of a zoomed-in timeline and of a drag's landing spot: one font, about 2.5 times smaller than the hours.
@MainActor
struct TimelineMinuteLabelTests {
    @Test func minutesAreMuchSmallerThanTheHours() {
        let tokens = TestConfig.tokens
        let ratio = tokens.uiFont(.timelineHour).pointSize / tokens.uiFont(.timelineMinutes).pointSize
        #expect(ratio > 2, "half the size they used to have")
    }
}
