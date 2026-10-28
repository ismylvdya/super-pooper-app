import Testing
@testable import SuperPooperApp

/// The timeline opens at the first shown hour also when the all-day strip appears after it.
struct TimelineOpeningTests {
    @Test func aStripThatArrivesLaterMovesTheOpeningPosition() {
        var opening = TimelineOpening(startOffset: 400, stripHeight: 0)
        #expect(opening.offset == 400)
        #expect(opening.stripChanged(to: 40) == 360)
    }

    @Test func afterTheUserScrolledTheStripNoLongerMovesTheTimeline() {
        var opening = TimelineOpening(startOffset: 400, stripHeight: 0)
        opening.userScrolled()
        #expect(opening.stripChanged(to: 40) == nil)
    }

    @Test func theOffsetNeverGoesAboveTheStartOfTheDay() {
        #expect(TimelineOpening(startOffset: 20, stripHeight: 40).offset == 0)
    }
}
