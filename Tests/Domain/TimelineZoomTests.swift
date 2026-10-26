import Foundation
import Testing
@testable import SuperPooper

/// Pinching the timeline zooms around the point between the fingers, not around the top.
struct TimelineZoomTests {
    @Test func theMomentUnderTheFingersStaysPut() {
        // 80 pt hours, scrolled 400 pt down, fingers 200 pt below the top: 7.5 hours in (after an 8 pt margin).
        let offset = TimelineZoom.offset(keeping: 200, startOffset: 400, contentTop: 8, from: 80, to: 160)
        let hoursBefore = (400.0 + 200 - 8) / 80
        let hoursAfter = (offset + 200 - 8) / 160
        #expect(abs(hoursBefore - hoursAfter) < 0.0001)
        #expect(TimelineZoom.offset(keeping: 200, startOffset: 400, contentTop: 8, from: 80, to: 80) == 400)
    }
}
